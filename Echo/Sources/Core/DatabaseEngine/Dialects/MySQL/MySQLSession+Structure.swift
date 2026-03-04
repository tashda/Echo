import Foundation
import MySQLNIO

extension MySQLSession {
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let columns = try await getTableSchema(table, schemaName: schema).map { column -> TableStructureDetails.Column in
            TableStructureDetails.Column(
                name: column.name,
                dataType: column.dataType,
                isNullable: column.isNullable,
                defaultValue: nil,
                generatedExpression: nil
            )
        }

        let primaryKey = try await fetchPrimaryKey(schema: schema, table: table)
        let indexes = try await fetchIndexes(schema: schema, table: table)
        let uniqueConstraints = indexes.filter { $0.isUnique }.map {
            TableStructureDetails.UniqueConstraint(name: $0.name, columns: $0.columns.map(\.name))
        }
        let foreignKeys = try await fetchForeignKeys(schema: schema, table: table)
        let dependencies = try await fetchDependencies(schema: schema, table: table)

        return TableStructureDetails(
            columns: columns,
            primaryKey: primaryKey,
            indexes: indexes,
            uniqueConstraints: uniqueConstraints,
            foreignKeys: foreignKeys,
            dependencies: dependencies
        )
    }

    private func fetchPrimaryKey(schema: String, table: String) async throws -> TableStructureDetails.PrimaryKey? {
        let sql = """
        SELECT k.constraint_name, k.column_name
        FROM information_schema.table_constraints t
        JOIN information_schema.key_column_usage k
          ON k.constraint_name = t.constraint_name
         AND k.table_schema = t.table_schema
        WHERE t.table_schema = ?
          AND t.table_name = ?
          AND t.constraint_type = 'PRIMARY KEY'
        ORDER BY k.ordinal_position;
        """
        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: table)])
        guard !rows.isEmpty else { return nil }
        let name = makeString(rows.first!, index: 0) ?? "PRIMARY"
        let columns = rows.compactMap { makeString($0, index: 1) }
        return TableStructureDetails.PrimaryKey(name: name, columns: columns)
    }

    private func fetchIndexes(schema: String, table: String) async throws -> [TableStructureDetails.Index] {
        let sql = """
        SELECT
            index_name,
            non_unique,
            seq_in_index,
            column_name,
            collation
        FROM information_schema.statistics
        WHERE table_schema = ? AND table_name = ?
        ORDER BY index_name, seq_in_index;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: table)])

        var grouped: [String: (isUnique: Bool, columns: [TableStructureDetails.Index.Column], filter: String?)] = [:]
        for row in rows {
            guard let name = makeString(row, index: 0) else { continue }
            let isUnique = (makeString(row, index: 1) ?? "1") == "0"
            let position = Int(makeString(row, index: 2) ?? "0") ?? 0
            guard let columnName = makeString(row, index: 3) else { continue }
            let collation = makeString(row, index: 4)
            let sortOrder: TableStructureDetails.Index.Column.SortOrder = collation == "D" ? .descending : .ascending
            var entry = grouped[name] ?? (isUnique, [], nil)
            entry.isUnique = entry.isUnique && isUnique
            entry.columns.append(TableStructureDetails.Index.Column(name: columnName, position: position, sortOrder: sortOrder))
            grouped[name] = entry
        }

        return grouped.compactMap { name, value in
            guard name.uppercased() != "PRIMARY" else { return nil }
            let sortedColumns = value.columns.sorted { $0.position < $1.position }
            return TableStructureDetails.Index(
                name: name,
                columns: sortedColumns,
                isUnique: value.isUnique,
                filterCondition: value.filter
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func fetchForeignKeys(schema: String, table: String) async throws -> [TableStructureDetails.ForeignKey] {
        let sql = """
        SELECT
            rc.constraint_name,
            kcu.column_name,
            kcu.referenced_table_schema,
            kcu.referenced_table_name,
            kcu.referenced_column_name,
            rc.update_rule,
            rc.delete_rule,
            kcu.ordinal_position
        FROM information_schema.referential_constraints rc
        JOIN information_schema.key_column_usage kcu
          ON rc.constraint_name = kcu.constraint_name
         AND rc.constraint_schema = kcu.constraint_schema
        WHERE rc.constraint_schema = ?
          AND rc.table_name = ?
        ORDER BY rc.constraint_name, kcu.ordinal_position;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: table)])
        var grouped: [String: (columns: [String], referencedSchema: String, referencedTable: String, referencedColumns: [String], onUpdate: String?, onDelete: String?)] = [:]

        for row in rows {
            guard let name = makeString(row, index: 0) else { continue }
            let column = makeString(row, index: 1)
            let refSchema = makeString(row, index: 2) ?? schema
            let refTable = makeString(row, index: 3) ?? ""
            let refColumn = makeString(row, index: 4)
            let onUpdate = makeString(row, index: 5)
            let onDelete = makeString(row, index: 6)

            var entry = grouped[name] ?? ([], refSchema, refTable, [], onUpdate, onDelete)
            if let column { entry.columns.append(column) }
            if let refColumn { entry.referencedColumns.append(refColumn) }
            entry.onUpdate = onUpdate
            entry.onDelete = onDelete
            grouped[name] = entry
        }

        return grouped.map { name, value in
            TableStructureDetails.ForeignKey(
                name: name,
                columns: value.columns,
                referencedSchema: value.referencedSchema,
                referencedTable: value.referencedTable,
                referencedColumns: value.referencedColumns,
                onUpdate: value.onUpdate,
                onDelete: value.onDelete
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func fetchDependencies(schema: String, table: String) async throws -> [TableStructureDetails.Dependency] {
        let sql = """
        SELECT
            kcu.constraint_name,
            kcu.column_name,
            kcu.referenced_table_name,
            kcu.referenced_column_name,
            rc.update_rule,
            rc.delete_rule
        FROM information_schema.key_column_usage kcu
        JOIN information_schema.referential_constraints rc
          ON rc.constraint_name = kcu.constraint_name
         AND rc.constraint_schema = kcu.constraint_schema
        WHERE kcu.referenced_table_schema = ?
          AND kcu.referenced_table_name = ?
        ORDER BY kcu.constraint_name, kcu.ordinal_position;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: table)])
        var grouped: [String: TableStructureDetails.Dependency] = [:]

        for row in rows {
            guard let name = makeString(row, index: 0) else { continue }
            let column = makeString(row, index: 1)
            let baseTable = makeString(row, index: 2)
            let refColumn = makeString(row, index: 3)
            let onUpdate = makeString(row, index: 4)
            let onDelete = makeString(row, index: 5)

            var dependency = grouped[name] ?? TableStructureDetails.Dependency(
                name: name,
                baseColumns: [],
                referencedTable: baseTable ?? "",
                referencedColumns: [],
                onUpdate: onUpdate,
                onDelete: onDelete
            )

            if let column { dependency.baseColumns.append(column) }
            if let refColumn { dependency.referencedColumns.append(refColumn) }
            dependency.onUpdate = onUpdate
            dependency.onDelete = onDelete
            grouped[name] = dependency
        }

        return Array(grouped.values).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

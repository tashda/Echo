import Foundation
import SQLiteNIO

extension SQLiteSession: DatabaseMetadataSession {
    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let sql = """
        SELECT name, type
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type IN ('table', 'view')
          AND name NOT LIKE 'sqlite_%'
        ORDER BY name;
        """
        let rows = try await connection.query(sql)
        return await MainActor.run {
            rows.compactMap { row -> SchemaObjectInfo? in
                guard
                    let name = row.column("name")?.string,
                    let type = row.column("type")?.string,
                    let objectType = SchemaObjectInfo.ObjectType(sqliteType: type)
                else { return nil }
                return SchemaObjectInfo(name: name, schema: databaseName, type: objectType)
            }
        }
    }

    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let databaseName = normalizedDatabaseName(schemaName)

        // Load tables and views with columns and FK info
        let tablesAndViews = try await listTablesAndViews(schema: databaseName)
        var enrichedObjects: [SchemaObjectInfo] = []

        for (index, object) in tablesAndViews.enumerated() {
            await progress?(object.type, index + 1, tablesAndViews.count)

            // Enrich tables with column + FK data
            if object.type == .table {
                let columns = try await getTableSchema(object.name, schemaName: databaseName)
                let rawForeignKeys = try await fetchForeignKeys(schema: databaseName, table: object.name)

                // Annotate columns with FK references
                let enrichedColumns = columns.map { column -> ColumnInfo in
                    for fk in rawForeignKeys {
                        if let colIndex = fk.columns.firstIndex(of: column.name),
                           colIndex < fk.referencedColumns.count {
                            return ColumnInfo(
                                name: column.name,
                                dataType: column.dataType,
                                isPrimaryKey: column.isPrimaryKey,
                                isNullable: column.isNullable,
                                maxLength: column.maxLength,
                                foreignKey: ColumnInfo.ForeignKeyReference(
                                    constraintName: "fk_\(object.name)_\(fk.id)",
                                    referencedSchema: databaseName,
                                    referencedTable: fk.referencedTable,
                                    referencedColumn: fk.referencedColumns[colIndex]
                                )
                            )
                        }
                    }
                    return column
                }
                enrichedObjects.append(SchemaObjectInfo(
                    name: object.name,
                    schema: databaseName,
                    type: object.type,
                    columns: enrichedColumns
                ))
            } else {
                enrichedObjects.append(object)
            }
        }

        // Load triggers
        let triggers = try await listTriggers(schema: databaseName)
        await progress?(.trigger, triggers.count, triggers.count)

        let objects = enrichedObjects + triggers
        return SchemaInfo(name: databaseName, objects: objects)
    }

    func listTriggers(schema: String?) async throws -> [SchemaObjectInfo] {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let sql = """
        SELECT name, sql
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type = 'trigger'
          AND name NOT LIKE 'sqlite_%'
        ORDER BY name;
        """
        let rows = try await connection.query(sql)
        return rows.compactMap { row -> SchemaObjectInfo? in
            guard let name = row.column("name")?.string else { return nil }
            let createSQL = row.column("sql")?.string ?? ""
            let (action, table) = Self.parseTriggerSQL(createSQL)
            return SchemaObjectInfo(
                name: name,
                schema: databaseName,
                type: .trigger,
                columns: [],
                triggerAction: action,
                triggerTable: table
            )
        }
    }

    func listDatabases() async throws -> [String] {
        let connection = try requireConnection()
        let rows = try await connection.query("PRAGMA database_list;")
        let names = rows.compactMap { $0.column("name")?.string }
        return names.isEmpty ? [normalizedDatabaseName(nil)] : names
    }

    func listSchemas() async throws -> [String] {
        try await listDatabases()
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schemaName)
        let pragma = "PRAGMA \(databaseName).table_info('\(escapeSingleQuotes(tableName))');"
        let rows = try await connection.query(pragma)

        let rawColumns = rows.compactMap { row -> SQLiteRawColumn? in
            guard let name = row.column("name")?.string else { return nil }
            let type = row.column("type")?.string ?? ""
            let notNull = (row.column("notnull")?.integer ?? 0) != 0
            let pk = (row.column("pk")?.integer ?? 0) != 0
            return SQLiteRawColumn(
                name: name,
                dataType: type.isEmpty ? "TEXT" : type,
                isPrimaryKey: pk,
                isNullable: !notNull,
                maxLength: nil
            )
        }

        return await MainActor.run {
            rawColumns.map { column in
                ColumnInfo(
                    name: column.name,
                    dataType: column.dataType,
                    isPrimaryKey: column.isPrimaryKey,
                    isNullable: column.isNullable,
                    maxLength: column.maxLength
                )
            }
        }
    }

    func getObjectDefinition(
        objectName: String,
        schemaName: String,
        objectType: SchemaObjectInfo.ObjectType,
        database: String? = nil
    ) async throws -> String {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schemaName)
        let typeString: String
        switch objectType {
        case .table: typeString = "table"
        case .view: typeString = "view"
        case .trigger: typeString = "trigger"
        case .materializedView, .function, .procedure, .extension, .sequence, .type, .synonym:
            throw DatabaseError.queryError("SQLite does not support definitions for \(objectType.rawValue)")
        }

        let sql = """
        SELECT sql
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type = '\(typeString)'
          AND name = ?
        LIMIT 1;
        """

        let rows = try await connection.query(sql, [SQLiteData.text(objectName)])
        guard let definition = rows.first?.column("sql")?.string else {
            throw DatabaseError.queryError("Definition for \(objectName) was not found")
        }
        return definition
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let columnsInfo = try await getTableSchema(table, schemaName: schema)
        let rawIndexes = try await fetchIndexes(schema: schema, table: table)
        let rawForeignKeys = try await fetchForeignKeys(schema: schema, table: table)
        let normalizedSchemaName = normalizedDatabaseName(schema)

        return await MainActor.run {
            let columns = columnsInfo.map { column in
                TableStructureDetails.Column(
                    name: column.name,
                    dataType: column.dataType,
                    isNullable: column.isNullable,
                    defaultValue: nil,
                    generatedExpression: nil
                )
            }

            let primaryKeyColumns = columnsInfo.filter(\.isPrimaryKey).map(\.name)
            let primaryKey = primaryKeyColumns.isEmpty
                ? nil
                : TableStructureDetails.PrimaryKey(name: "primary_key", columns: primaryKeyColumns)

            let indexes = rawIndexes.map { index in
                let indexColumns = index.columns.map { column -> TableStructureDetails.Index.Column in
                    TableStructureDetails.Index.Column(
                        name: column.name,
                        position: column.position,
                        sortOrder: column.isAscending ? .ascending : .descending
                    )
                }
                return TableStructureDetails.Index(
                    name: index.name,
                    columns: indexColumns,
                    isUnique: index.isUnique,
                    filterCondition: index.filterCondition
                )
            }

            let uniqueConstraints = indexes
                .filter(\.isUnique)
                .map { TableStructureDetails.UniqueConstraint(name: $0.name, columns: $0.columns.map(\.name)) }

            let foreignKeys = rawForeignKeys.map { key in
                TableStructureDetails.ForeignKey(
                    name: "fk_\(table)_\(key.id)",
                    columns: key.columns,
                    referencedSchema: normalizedSchemaName,
                    referencedTable: key.referencedTable,
                    referencedColumns: key.referencedColumns,
                    onUpdate: key.onUpdate,
                    onDelete: key.onDelete
                )
            }

            return TableStructureDetails(
                columns: columns,
                primaryKey: primaryKey,
                indexes: indexes,
                uniqueConstraints: uniqueConstraints,
                foreignKeys: foreignKeys,
                dependencies: []
            )
        }
    }

    private func fetchIndexes(schema: String, table: String) async throws -> [SQLiteRawIndex] {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let pragma = "PRAGMA \(databaseName).index_list('\(escapeSingleQuotes(table))');"
        let rows = try await connection.query(pragma)

        var collected: [SQLiteRawIndex] = []
        for row in rows {
            guard let indexName = row.column("name")?.string else { continue }
            let isUnique = (row.column("unique")?.integer ?? 0) != 0
            let columns = try await fetchIndexColumns(databaseName: databaseName, indexName: indexName)
            let hasWhereClause = (row.column("partial")?.integer ?? 0) != 0
            let filterCondition = hasWhereClause ? try await fetchIndexWhereClause(databaseName: databaseName, indexName: indexName) : nil
            collected.append(
                SQLiteRawIndex(
                    name: indexName,
                    isUnique: isUnique,
                    columns: columns,
                    filterCondition: filterCondition
                )
            )
        }
        return collected
    }

    private func fetchIndexColumns(databaseName: String, indexName: String) async throws -> [SQLiteRawIndexColumn] {
        let connection = try requireConnection()
        let pragma = "PRAGMA \(databaseName).index_xinfo('\(escapeSingleQuotes(indexName))');"
        let rows = try await connection.query(pragma)

        var columns: [SQLiteRawIndexColumn] = []
        for row in rows {
            let isKey = (row.column("key")?.integer ?? 0) != 0
            guard isKey else { continue }
            let position = row.column("seqno")?.integer ?? 0
            guard let name = row.column("name")?.string else { continue }
            let isAscending = (row.column("desc")?.integer ?? 0) == 0
            columns.append(SQLiteRawIndexColumn(name: name, position: position, isAscending: isAscending))
        }
        return columns.sorted { $0.position < $1.position }
    }

    private func fetchIndexWhereClause(databaseName: String, indexName: String) async throws -> String? {
        let connection = try requireConnection()
        let sql = """
        SELECT sql
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type = 'index' AND name = ?
        LIMIT 1;
        """
        let rows = try await connection.query(sql, [SQLiteData.text(indexName)])
        guard let definition = rows.first?.column("sql")?.string else { return nil }
        if let range = definition.range(of: "WHERE", options: .caseInsensitive) {
            let whereClause = definition[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return whereClause.isEmpty ? nil : whereClause
        }
        return nil
    }

    private func fetchForeignKeys(schema: String, table: String) async throws -> [SQLiteRawForeignKey] {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let pragma = "PRAGMA \(databaseName).foreign_key_list('\(escapeSingleQuotes(table))');"
        let rows = try await connection.query(pragma)

        struct GroupedEntry {
            var table: String
            var columns: [String]
            var references: [String]
            var onUpdate: String?
            var onDelete: String?
        }

        var grouped: [Int: GroupedEntry] = [:]

        for row in rows {
            guard
                let id = row.column("id")?.integer,
                let referencedTable = row.column("table")?.string,
                let fromColumn = row.column("from")?.string,
                let toColumn = row.column("to")?.string
            else { continue }

            let sequence = row.column("seq")?.integer ?? 0
            let onUpdate = row.column("on_update")?.string
            let onDelete = row.column("on_delete")?.string

            var entry = grouped[id] ?? GroupedEntry(table: referencedTable, columns: [], references: [], onUpdate: onUpdate, onDelete: onDelete)

            if entry.columns.count <= sequence {
                entry.columns.append(fromColumn)
            } else {
                entry.columns.insert(fromColumn, at: sequence)
            }

            if entry.references.count <= sequence {
                entry.references.append(toColumn)
            } else {
                entry.references.insert(toColumn, at: sequence)
            }

            if entry.onUpdate == nil {
                entry.onUpdate = onUpdate
            }
            if entry.onDelete == nil {
                entry.onDelete = onDelete
            }

            grouped[id] = entry
        }

        return grouped.keys.sorted().compactMap { key in
            guard let entry = grouped[key] else { return nil }
            return SQLiteRawForeignKey(
                id: key,
                referencedTable: entry.table,
                columns: entry.columns,
                referencedColumns: entry.references,
                onUpdate: entry.onUpdate,
                onDelete: entry.onDelete
            )
        }
    }

    // MARK: - Trigger SQL Parsing

    /// Parses a CREATE TRIGGER statement to extract the action (e.g. "AFTER INSERT")
    /// and the target table name.
    static func parseTriggerSQL(_ sql: String) -> (action: String?, table: String?) {
        let upper = sql.uppercased()

        // Extract timing: BEFORE, AFTER, or INSTEAD OF
        var timing: String?
        if upper.contains("INSTEAD OF") {
            timing = "INSTEAD OF"
        } else if upper.contains("BEFORE") {
            timing = "BEFORE"
        } else if upper.contains("AFTER") {
            timing = "AFTER"
        }

        // Extract event: INSERT, UPDATE, DELETE
        var event: String?
        for keyword in ["INSERT", "UPDATE", "DELETE"] {
            if upper.contains(keyword) {
                event = keyword
                break
            }
        }

        let action = [timing, event].compactMap { $0 }.joined(separator: " ")

        // Extract table name from "ON table_name"
        var table: String?
        if let onRange = upper.range(of: "\\bON\\s+", options: .regularExpression) {
            let afterON = sql[onRange.upperBound...]
            let tableName = afterON.prefix(while: { !$0.isWhitespace && $0 != "(" && $0 != "\n" })
            if !tableName.isEmpty {
                // Strip quotes if present
                let cleaned = tableName
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`[]"))
                table = cleaned
            }
        }

        return (action.isEmpty ? nil : action, table)
    }

    // MARK: - PRAGMA Browser Support

    /// Fetches the value of a single PRAGMA for the given database.
    func fetchPragmaValue(_ pragma: String, schema: String?) async throws -> String? {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let sql = "PRAGMA \(databaseName).\(pragma);"
        let rows = try await connection.query(sql)
        guard let firstRow = rows.first else { return nil }
        // PRAGMAs return a column named after the pragma
        if let value = firstRow.column(pragma) {
            return value.string ?? value.integer.map(String.init)
        }
        return nil
    }

    // MARK: - Attach/Detach Database

    func attachSQLiteDatabase(path: String, alias: String) async throws {
        let connection = try requireConnection()
        let sql = "ATTACH DATABASE '\(escapeSingleQuotes(path))' AS \(quoteIdentifier(alias));"
        _ = try await connection.query(sql)
    }

    func detachSQLiteDatabase(alias: String) async throws {
        let connection = try requireConnection()
        let sql = "DETACH DATABASE \(quoteIdentifier(alias));"
        _ = try await connection.query(sql)
    }
}

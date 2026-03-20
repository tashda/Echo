import Foundation
import MySQLNIO
import NIOCore

extension MySQLSession {
    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName: String
        if let schema, !schema.isEmpty {
            schemaName = schema
        } else if let defaultDatabase, !defaultDatabase.isEmpty {
            schemaName = defaultDatabase
        } else if let current = try await currentDatabaseName(), !current.isEmpty {
            schemaName = current
        } else {
            return []
        }

        let sql = """
        SELECT
            table_name,
            table_type
        FROM information_schema.tables
        WHERE table_schema = ?
        ORDER BY table_name;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schemaName)])
        return rows.compactMap { row in
            guard
                row.columnDefinitions.count >= 2,
                let name = makeString(row, index: 0),
                let type = makeString(row, index: 1)
            else { return nil }

            guard let objectType = SchemaObjectInfo.ObjectType(mysqlTableType: type) else {
                return nil
            }

            return SchemaObjectInfo(name: name, schema: schemaName, type: objectType)
        }
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema: String
        if let schemaName, !schemaName.isEmpty {
            schema = schemaName
        } else if let defaultDatabase, !defaultDatabase.isEmpty {
            schema = defaultDatabase
        } else if let current = try await currentDatabaseName(), !current.isEmpty {
            schema = current
        } else {
            return []
        }

        let sql = """
        SELECT
            column_name,
            data_type,
            is_nullable,
            column_key,
            character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = ? AND table_name = ?
        ORDER BY ordinal_position;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: tableName)])
        return rows.compactMap { row in
            guard
                let name = makeString(row, index: 0),
                let dataType = makeString(row, index: 1),
                let nullable = makeString(row, index: 2)
            else { return nil }
            let key = makeString(row, index: 3)
            let lengthString = makeString(row, index: 4)
            let maxLength = lengthString.flatMap { Int($0) }
            return ColumnInfo(
                name: name,
                dataType: dataType,
                isPrimaryKey: key == "PRI",
                isNullable: nullable.uppercased() != "NO",
                maxLength: maxLength
            )
        }
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        let qualifiedName = "`\(schemaName.replacingOccurrences(of: "`", with: "``"))`.`\(objectName.replacingOccurrences(of: "`", with: "``"))`"
        let sql: String
        switch objectType {
        case .table:
            sql = "SHOW CREATE TABLE \(qualifiedName)"
        case .view:
            sql = "SHOW CREATE VIEW \(qualifiedName)"
        case .materializedView:
            throw DatabaseError.queryError("MySQL does not support materialized views")
        case .function:
            sql = "SHOW CREATE FUNCTION `\(objectName.replacingOccurrences(of: "`", with: "``"))`"
        case .procedure:
            sql = "SHOW CREATE PROCEDURE `\(objectName.replacingOccurrences(of: "`", with: "``"))`"
        case .trigger:
            sql = "SHOW CREATE TRIGGER `\(objectName.replacingOccurrences(of: "`", with: "``"))`"
        case .extension:
            throw DatabaseError.queryError("MySQL does not support extensions")
        case .sequence:
            throw DatabaseError.queryError("MySQL does not support sequences")
        case .type:
            throw DatabaseError.queryError("MySQL does not support user-defined types")
        case .synonym:
            throw DatabaseError.queryError("MySQL does not support synonyms")
        }

        let rows = try await connection.simpleQuery(sql).get()
        guard let row = rows.first else {
            throw DatabaseError.queryError("Definition not found")
        }

        if let create = row.values.last ?? nil {
            let data = MySQLData(
                type: row.columnDefinitions.last?.columnType ?? .varString,
                format: row.format,
                buffer: create,
                isUnsigned: row.columnDefinitions.last?.flags.contains(.COLUMN_UNSIGNED) ?? false
            )
            return data.string ?? ""
        }

        let combined = row.values.compactMap { buffer -> String? in
            guard let buffer else { return nil }
            return buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes)
        }
        if let definition = combined.last {
            return definition
        }
        throw DatabaseError.queryError("Unable to decode object definition")
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        var affectedRows: Int = 0
        let future = connection.query(sql, onMetadata: { metadata in
            affectedRows = Int(metadata.affectedRows)
        })
        do {
            _ = try await future.get()
            return affectedRows
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        return DatabaseMaintenanceResult(operation: "Rebuild", messages: ["Not implemented"], succeeded: false)
    }

    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        return DatabaseMaintenanceResult(operation: "Rebuild", messages: ["Not implemented"], succeeded: false)
    }

    func dropIndex(schema: String, name: String) async throws {
        _ = try await executeUpdate("DROP INDEX `\(name.replacingOccurrences(of: "`", with: "``"))` ON `\(schema.replacingOccurrences(of: "`", with: "``"))`.`\(name.replacingOccurrences(of: "`", with: "``"))`")
    }

    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws {
        _ = try await simpleQuery("OPTIMIZE TABLE `\(schema)`.`\(table)`")
    }

    func analyzeTable(schema: String, table: String) async throws {
        _ = try await simpleQuery("ANALYZE TABLE `\(schema)`.`\(table)`")
    }

    func reindexTable(schema: String, table: String) async throws {
        _ = try await simpleQuery("OPTIMIZE TABLE `\(schema)`.`\(table)`")
    }

    func listFragmentedIndexes() async throws -> [SQLServerIndexFragmentation] {
        []
    }

    func getDatabaseHealth() async throws -> SQLServerDatabaseHealth {
        SQLServerDatabaseHealth(name: "", owner: "", createDate: Date(), sizeMB: 0, recoveryModel: "", status: "", compatibilityLevel: 0, collationName: nil)
    }

    func getBackupHistory(limit: Int) async throws -> [SQLServerBackupHistoryEntry] {
        []
    }

    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult {
        DatabaseMaintenanceResult(operation: "Check Integrity", messages: ["Not implemented"], succeeded: false)
    }

    func shrinkDatabase() async throws -> DatabaseMaintenanceResult {
        DatabaseMaintenanceResult(operation: "Shrink", messages: ["Not implemented"], succeeded: false)
    }

    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        _ = try await simpleQuery("ANALYZE TABLE `\(schema)`.`\(table)`")
        return DatabaseMaintenanceResult(operation: "Analyze", messages: ["Table analyzed."], succeeded: true)
    }
}

extension MySQLSession: DatabaseMetadataSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let tableSQL = """
        SELECT
            t.table_name,
            t.table_type,
            c.column_name,
            c.data_type,
            c.is_nullable,
            c.column_key,
            c.character_maximum_length,
            c.ordinal_position
        FROM information_schema.tables t
        LEFT JOIN information_schema.columns c
          ON c.table_schema = t.table_schema
         AND c.table_name = t.table_name
        WHERE t.table_schema = ? AND t.table_type IN ('BASE TABLE', 'VIEW')
        ORDER BY t.table_name, c.ordinal_position;
        """

        let (rows, _) = try await performQuery(tableSQL, binds: [MySQLData(string: schemaName)])

        var grouped: [String: SchemaObjectAccumulator] = [:]
        for row in rows {
            guard
                let name = makeString(row, index: 0),
                let type = makeString(row, index: 1)
            else { continue }

            let objectType = SchemaObjectInfo.ObjectType(mysqlTableType: type) ?? .table
            var accumulator = grouped[name] ?? SchemaObjectAccumulator(type: objectType)
            if let columnName = makeString(row, index: 2) {
                let dataType = makeString(row, index: 3) ?? ""
                let nullable = makeString(row, index: 4)
                let columnKey = makeString(row, index: 5)
                let length = makeString(row, index: 6)
                let column = ColumnInfo(
                    name: columnName,
                    dataType: dataType,
                    isPrimaryKey: columnKey == "PRI",
                    isNullable: (nullable ?? "YES").uppercased() != "NO",
                    maxLength: length.flatMap { Int($0) }
                )
                accumulator.columns.append(column)
            }
            grouped[name] = accumulator
        }

        if let progress {
            let orderedNames = grouped.keys.sorted()
            for (index, name) in orderedNames.enumerated() {
                if let type = grouped[name]?.type {
                    await progress(type, index + 1, orderedNames.count)
                }
            }
        }

        let tables: [SchemaObjectInfo] = grouped.map { name, accumulator in
            SchemaObjectInfo(
                name: name,
                schema: schemaName,
                type: accumulator.type,
                columns: accumulator.columns
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let functions = try await loadRoutineObjects(schemaName: schemaName, progress: progress)
        let triggers = try await loadTriggerObjects(schemaName: schemaName, progress: progress)

        let objects = tables + functions + triggers
        return SchemaInfo(name: schemaName, objects: objects)
    }

    private func loadRoutineObjects(
        schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> [SchemaObjectInfo] {
        let sql = """
        SELECT routine_name, routine_type
        FROM information_schema.routines
        WHERE routine_schema = ?
        ORDER BY routine_name;
        """
        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schemaName)])
        if let progress {
            for (index, row) in rows.enumerated() {
                if let kind = makeString(row, index: 1), let type = SchemaObjectInfo.ObjectType(mysqlRoutineType: kind) {
                    await progress(type, index + 1, rows.count)
                }
            }
        }
        return rows.compactMap { row in
            guard
                let name = makeString(row, index: 0),
                let routineType = makeString(row, index: 1),
                let type = SchemaObjectInfo.ObjectType(mysqlRoutineType: routineType)
            else { return nil }
            return SchemaObjectInfo(name: name, schema: schemaName, type: type)
        }
    }

    private func loadTriggerObjects(
        schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> [SchemaObjectInfo] {
        let sql = """
        SELECT trigger_name, event_manipulation, event_object_table
        FROM information_schema.triggers
        WHERE trigger_schema = ?
        ORDER BY trigger_name;
        """
        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schemaName)])
        if let progress {
            for (index, _) in rows.enumerated() {
                await progress(.trigger, index + 1, rows.count)
            }
        }
        return rows.compactMap { row in
            guard let name = makeString(row, index: 0) else { return nil }
            let action = makeString(row, index: 1)
            let table = makeString(row, index: 2)
            return SchemaObjectInfo(name: name, schema: schemaName, type: .trigger, columns: [], triggerAction: action, triggerTable: table)
        }
    }

    func listAvailableExtensions() async throws -> [AvailableExtensionInfo] {
        []
    }

    func installExtension(name: String, schema: String?, version: String?, cascade: Bool) async throws {
        throw DatabaseError.queryError("Extensions are not supported for MySQL")
    }

    private struct SchemaObjectAccumulator {
        let type: SchemaObjectInfo.ObjectType
        var columns: [ColumnInfo] = []
    }
}

internal extension SchemaObjectInfo.ObjectType {
    init?(mysqlTableType: String) {
        switch mysqlTableType.uppercased() {
        case "BASE TABLE": self = .table
        case "VIEW": self = .view
        default: return nil
        }
    }

    init?(mysqlRoutineType: String) {
        switch mysqlRoutineType.uppercased() {
        case "FUNCTION": self = .function
        case "PROCEDURE": self = .procedure
        default: return nil
        }
    }
}

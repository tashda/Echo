import Foundation
import MySQLKit
import MySQLWire

extension MySQLSession {
    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring {
        MySQLActivityMonitorWrapper(session: self)
    }

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

        let objects = try await client.metadata.listTablesAndViews(in: schemaName)
        return objects.compactMap { object in
            guard let objectType = SchemaObjectInfo.ObjectType(mysqlSchemaObjectKind: object.kind) else {
                return nil
            }
            return SchemaObjectInfo(name: object.name, schema: schemaName, type: objectType)
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

        let columns = try await client.metadata.listColumns(in: tableName, schema: schema)
        return columns.map { col in
            ColumnInfo(
                name: col.name,
                dataType: col.dataType,
                isPrimaryKey: col.isPrimaryKey,
                isNullable: col.isNullable,
                maxLength: col.maxLength
            )
        }
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType, database: String? = nil) async throws -> String {
        guard let kind = objectType.mysqlSchemaObjectKind else {
            throw DatabaseError.queryError("MySQL does not support \(objectType) objects")
        }
        return try await client.metadata.objectDefinition(named: objectName, schema: schemaName, kind: kind)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        do {
            let result = try await client.query(sql)
            if let metadata = result.metadata {
                return Int(metadata.affectedRows)
            }
            return result.rows.count
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    func dropTable(schema: String?, name: String, ifExists: Bool) async throws {
        let ifExistsClause = ifExists ? "IF EXISTS " : ""
        let qualifiedName = schema.map { "`\($0)`.`\(name)`" } ?? "`\(name)`"
        _ = try await executeUpdate("DROP TABLE \(ifExistsClause)\(qualifiedName)")
    }

    func truncateTable(schema: String?, name: String) async throws {
        let qualifiedName = schema.map { "`\($0)`.`\(name)`" } ?? "`\(name)`"
        _ = try await executeUpdate("TRUNCATE TABLE \(qualifiedName)")
    }

    func renameTable(schema: String?, oldName: String, newName: String) async throws {
        let qualifiedOld = schema.map { "`\($0)`.`\(oldName)`" } ?? "`\(oldName)`"
        let qualifiedNew = schema.map { "`\($0)`.`\(newName)`" } ?? "`\(newName)`"
        _ = try await executeUpdate("RENAME TABLE \(qualifiedOld) TO \(qualifiedNew)")
    }

    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        DatabaseMaintenanceResult(operation: "Rebuild", messages: ["Not implemented"], succeeded: false)
    }

    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        DatabaseMaintenanceResult(operation: "Rebuild", messages: ["Not implemented"], succeeded: false)
    }

    func dropIndex(schema: String, name: String) async throws {
        try await client.indexes.dropIndex(schema: schema, name: name)
    }

    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws {
        _ = try await client.maintenance.optimizeTable(schema: schema, table: table)
    }

    func analyzeTable(schema: String, table: String) async throws {
        _ = try await client.maintenance.analyzeTable(schema: schema, table: table)
    }

    func reindexTable(schema: String, table: String) async throws {
        _ = try await client.maintenance.optimizeTable(schema: schema, table: table)
    }

    func listFragmentedIndexes() async throws -> [SQLServerIndexFragmentation] {
        []
    }

    func getDatabaseHealth() async throws -> SQLServerDatabaseHealth {
        let dbName: String
        if let defaultDatabase, !defaultDatabase.isEmpty {
            dbName = defaultDatabase
        } else if let current = try await currentDatabaseName(), !current.isEmpty {
            dbName = current
        } else {
            dbName = "unknown"
        }

        let info = try await client.metadata.databaseInfo(schema: dbName)
        let status = info.characterSet.map { "Charset: \($0)" } ?? "Online"

        return SQLServerDatabaseHealth(
            name: dbName,
            owner: "",
            createDate: Date(),
            sizeMB: info.sizeMB,
            recoveryModel: "",
            status: status,
            compatibilityLevel: 0,
            collationName: info.collation
        )
    }

    func getBackupHistory(limit: Int) async throws -> [SQLServerBackupHistoryEntry] {
        []
    }

    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult {
        let dbName: String
        if let defaultDatabase, !defaultDatabase.isEmpty {
            dbName = defaultDatabase
        } else if let current = try await currentDatabaseName(), !current.isEmpty {
            dbName = current
        } else {
            return DatabaseMaintenanceResult(operation: "Check Integrity", messages: ["No database selected."], succeeded: false)
        }

        let objects = try await client.metadata.listTablesAndViews(in: dbName)
        let tableNames = objects.filter { $0.kind == .table }.map(\.name)
        guard !tableNames.isEmpty else {
            return DatabaseMaintenanceResult(operation: "Check Integrity", messages: ["No tables found."], succeeded: true)
        }

        let result = try await client.maintenance.checkTables(schema: dbName, tables: tableNames)
        let hasError = result.messages.contains(where: { $0.lowercased().contains("error") || $0.lowercased().contains("corrupt") })

        return DatabaseMaintenanceResult(
            operation: "Check Integrity",
            messages: result.messages.isEmpty ? ["All tables passed integrity check."] : result.messages,
            succeeded: !hasError
        )
    }

    func shrinkDatabase() async throws -> DatabaseMaintenanceResult {
        DatabaseMaintenanceResult(operation: "Shrink", messages: ["Not implemented"], succeeded: false)
    }

    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        let result = try await client.maintenance.analyzeTable(schema: schema, table: table)
        return DatabaseMaintenanceResult(operation: "Analyze", messages: result.messages.isEmpty ? ["Table analyzed."] : result.messages, succeeded: true)
    }
}

extension MySQLSession: DatabaseMetadataSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let details = try await client.metadata.schemaDetails(schema: schemaName)

        if let progress {
            let orderedNames = details.map(\.name)
            for (index, detail) in details.enumerated() {
                let type = SchemaObjectInfo.ObjectType(mysqlSchemaObjectKind: detail.kind) ?? .table
                await progress(type, index + 1, orderedNames.count)
            }
        }

        let tables: [SchemaObjectInfo] = details.map { detail in
            let columns = detail.columns.map { col in
                ColumnInfo(
                    name: col.name,
                    dataType: col.dataType,
                    isPrimaryKey: col.isPrimaryKey,
                    isNullable: col.isNullable,
                    maxLength: col.maxLength
                )
            }
            let type = SchemaObjectInfo.ObjectType(mysqlSchemaObjectKind: detail.kind) ?? .table
            return SchemaObjectInfo(
                name: detail.name,
                schema: schemaName,
                type: type,
                columns: columns
            )
        }

        let routineObjects = try await loadRoutineObjects(schemaName: schemaName, progress: progress)
        let triggerObjects = try await loadTriggerObjects(schemaName: schemaName, progress: progress)

        let objects = tables + routineObjects + triggerObjects
        return SchemaInfo(name: schemaName, objects: objects)
    }

    private func loadRoutineObjects(
        schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> [SchemaObjectInfo] {
        let routines = try await client.metadata.listRoutines(in: schemaName)
        if let progress {
            for (index, routine) in routines.enumerated() {
                let type = SchemaObjectInfo.ObjectType(mysqlRoutineType: routine.type) ?? .function
                await progress(type, index + 1, routines.count)
            }
        }
        return routines.compactMap { routine in
            guard let type = SchemaObjectInfo.ObjectType(mysqlRoutineType: routine.type) else { return nil }
            return SchemaObjectInfo(name: routine.name, schema: schemaName, type: type)
        }
    }

    private func loadTriggerObjects(
        schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> [SchemaObjectInfo] {
        let triggers = try await client.metadata.listTriggers(in: schemaName)
        if let progress {
            for (index, _) in triggers.enumerated() {
                await progress(.trigger, index + 1, triggers.count)
            }
        }
        return triggers.map { trigger in
            SchemaObjectInfo(
                name: trigger.name,
                schema: schemaName,
                type: .trigger,
                columns: [],
                triggerAction: trigger.event,
                triggerTable: trigger.table
            )
        }
    }

    func listAvailableExtensions() async throws -> [AvailableExtensionInfo] {
        []
    }

    func installExtension(name: String, schema: String?, version: String?, cascade: Bool) async throws {
        throw DatabaseError.queryError("Extensions are not supported for MySQL")
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

    init?(mysqlSchemaObjectKind kind: MySQLSchemaObjectKind) {
        switch kind {
        case .table: self = .table
        case .view: self = .view
        case .function: self = .function
        case .procedure: self = .procedure
        case .trigger: self = .trigger
        case .event: return nil
        }
    }

    var mysqlSchemaObjectKind: MySQLSchemaObjectKind? {
        switch self {
        case .table: return .table
        case .view: return .view
        case .function: return .function
        case .procedure: return .procedure
        case .trigger: return .trigger
        case .materializedView, .extension, .sequence, .type, .synonym: return nil
        }
    }
}

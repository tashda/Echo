import Foundation

final class MockDatabaseSession: DatabaseSession, DatabaseMetadataSession, @unchecked Sendable {
    // MARK: - Call Tracking

    var closeCallCount = 0
    var simpleQueryCallCount = 0
    var listDatabasesCallCount = 0
    var listSchemasCallCount = 0
    var loadSchemaInfoCallCount = 0

    // MARK: - Handlers

    var simpleQueryHandler: (String) async throws -> QueryResultSet = { _ in
        QueryResultSet(columns: [], rows: [])
    }

    var listDatabasesHandler: () async throws -> [String] = { [] }
    var listSchemasHandler: () async throws -> [String] = { [] }
    var loadSchemaInfoHandler: (String, (nonisolated(nonsending) @Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?) async throws -> SchemaInfo = { schema, _ in
        SchemaInfo(name: schema, objects: [])
    }

    // MARK: - DatabaseSession Conformance

    func close() async {
        closeCallCount += 1
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        simpleQueryCallCount += 1
        return try await simpleQueryHandler(sql)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        simpleQueryCallCount += 1
        return try await simpleQueryHandler(sql)
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        simpleQueryCallCount += 1
        return try await simpleQueryHandler(sql)
    }

    func listDatabases() async throws -> [String] {
        listDatabasesCallCount += 1
        return try await listDatabasesHandler()
    }

    func listSchemas() async throws -> [String] {
        listSchemasCallCount += 1
        return try await listSchemasHandler()
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] { [] }
    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet { QueryResultSet(columns: [], rows: []) }
    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] { [] }
    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String { "" }
    func executeUpdate(_ sql: String) async throws -> Int { 0 }
    func renameTable(schema: String?, oldName: String, newName: String) async throws {}
    func dropTable(schema: String?, name: String, ifExists: Bool) async throws {}
    func truncateTable(schema: String?, name: String) async throws {}
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails { TableStructureDetails() }

    func loadSchemaInfo(
        _ schemaName: String,
        progress: (nonisolated(nonsending) @Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        loadSchemaInfoCallCount += 1
        return try await loadSchemaInfoHandler(schemaName, progress)
    }

    // MARK: - Maintenance Methods
    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult { DatabaseMaintenanceResult(operation: "Rebuild", messages: [], succeeded: true) }
    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult { DatabaseMaintenanceResult(operation: "Rebuild", messages: [], succeeded: true) }
    func dropIndex(schema: String, name: String) async throws {}
    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws {}
    func analyzeTable(schema: String, table: String) async throws {}
    func reindexTable(schema: String, table: String) async throws {}
    func listFragmentedIndexes() async throws -> [SQLServerIndexFragmentation] { [] }
    func getDatabaseHealth() async throws -> SQLServerDatabaseHealth {
        SQLServerDatabaseHealth(name: "", owner: "", createDate: Date(), sizeMB: 0, recoveryModel: "", status: "", compatibilityLevel: 0, collationName: nil)
    }
    func getBackupHistory(limit: Int) async throws -> [SQLServerBackupHistoryEntry] { [] }
    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult { DatabaseMaintenanceResult(operation: "Check Integrity", messages: [], succeeded: true) }
    func shrinkDatabase() async throws -> DatabaseMaintenanceResult { DatabaseMaintenanceResult(operation: "Shrink", messages: [], succeeded: true) }
    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult { DatabaseMaintenanceResult(operation: "Stats", messages: [], succeeded: true) }
    func updateIndexStatistics(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult { DatabaseMaintenanceResult(operation: "Stats", messages: [], succeeded: true) }
    func sessionForDatabase(_ database: String) async throws -> DatabaseSession { self }
    func currentDatabaseName() async throws -> String? { nil }
    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring { fatalError() }
    func listExtensionObjects(extensionName: String) async throws -> [ExtensionObjectInfo] { [] }
    func isSuperuser() async throws -> Bool { false }
}

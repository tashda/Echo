import Foundation
@testable import Echo

final class MockDatabaseSession: DatabaseSession, DatabaseMetadataSession, @unchecked Sendable {
    // MARK: - Call Tracking

    var closeCallCount = 0
    var simpleQueryCallCount = 0
    var listDatabasesCallCount = 0
    var listSchemasCallCount = 0
    var listTablesAndViewsCallCount = 0
    var queryWithPagingCallCount = 0
    var getTableSchemaCallCount = 0
    var getObjectDefinitionCallCount = 0
    var executeUpdateCallCount = 0
    var getTableStructureDetailsCallCount = 0
    var loadSchemaInfoCallCount = 0

    // MARK: - Handlers

    var closeHandler: () async -> Void = {}
    var simpleQueryHandler: (String) async throws -> QueryResultSet = { _ in
        QueryResultSet(columns: [], rows: [])
    }
    var simpleQueryWithProgressHandler: (String, QueryProgressHandler?) async throws -> QueryResultSet = { sql, _ in
        QueryResultSet(columns: [], rows: [])
    }
    var simpleQueryWithModeHandler: (String, ResultStreamingExecutionMode?, QueryProgressHandler?) async throws -> QueryResultSet = { sql, _, _ in
        QueryResultSet(columns: [], rows: [])
    }
    var listDatabasesHandler: () async throws -> [String] = { [] }
    var listSchemasHandler: () async throws -> [String] = { [] }
    var listTablesAndViewsHandler: (String?) async throws -> [SchemaObjectInfo] = { _ in [] }
    var queryWithPagingHandler: (String, Int, Int) async throws -> QueryResultSet = { _, _, _ in
        QueryResultSet(columns: [], rows: [])
    }
    var getTableSchemaHandler: (String, String?) async throws -> [ColumnInfo] = { _, _ in [] }
    var getObjectDefinitionHandler: (String, String, SchemaObjectInfo.ObjectType) async throws -> String = { _, _, _ in "" }
    var executeUpdateHandler: (String) async throws -> Int = { _ in 0 }
    var getTableStructureDetailsHandler: (String, String) async throws -> TableStructureDetails = { _, _ in
        TableStructureDetails()
    }
    var loadSchemaInfoHandler: (String, (nonisolated(nonsending) @Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?) async throws -> SchemaInfo = { name, _ in
        SchemaInfo(name: name, objects: [])
    }

    // MARK: - DatabaseSession

    func close() async {
        closeCallCount += 1
        await closeHandler()
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        simpleQueryCallCount += 1
        return try await simpleQueryHandler(sql)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        simpleQueryCallCount += 1
        return try await simpleQueryWithProgressHandler(sql, progressHandler)
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        simpleQueryCallCount += 1
        return try await simpleQueryWithModeHandler(sql, executionMode, progressHandler)
    }

    func listDatabases() async throws -> [String] {
        listDatabasesCallCount += 1
        return try await listDatabasesHandler()
    }

    func listSchemas() async throws -> [String] {
        listSchemasCallCount += 1
        return try await listSchemasHandler()
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        listTablesAndViewsCallCount += 1
        return try await listTablesAndViewsHandler(schema)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        queryWithPagingCallCount += 1
        return try await queryWithPagingHandler(sql, limit, offset)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        getTableSchemaCallCount += 1
        return try await getTableSchemaHandler(tableName, schemaName)
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        getObjectDefinitionCallCount += 1
        return try await getObjectDefinitionHandler(objectName, schemaName, objectType)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        executeUpdateCallCount += 1
        return try await executeUpdateHandler(sql)
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        getTableStructureDetailsCallCount += 1
        return try await getTableStructureDetailsHandler(schema, table)
    }

    // MARK: - DatabaseMetadataSession

    func loadSchemaInfo(
        _ schemaName: String,
        progress: (nonisolated(nonsending) @Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        loadSchemaInfoCallCount += 1
        return try await loadSchemaInfoHandler(schemaName, progress)
    }
}

import Foundation

public protocol DatabaseSession: Sendable {
    func close() async
    func simpleQuery(_ sql: String) async throws -> QueryResultSet
    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet
    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet
    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo]
    func listDatabases() async throws -> [String]
    func listSchemas() async throws -> [String]
    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet
    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo]
    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String
    func executeUpdate(_ sql: String) async throws -> Int
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails
}

public protocol DatabaseFactory: Sendable {
    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int
    ) async throws -> DatabaseSession
}

public protocol DatabaseMetadataSession: DatabaseSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo
}

public protocol DatabaseSchemaSummaryProviding: AnyObject {
    func loadSchemaSummary(_ schemaName: String) async throws -> SchemaInfo
}

public extension DatabaseSession {
    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: progressHandler)
    }
}

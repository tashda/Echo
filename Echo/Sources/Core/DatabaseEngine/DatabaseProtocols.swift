import Foundation

public protocol DatabaseSession: Sendable {
    func close() async
    func isSuperuser() async throws -> Bool
    func simpleQuery(_ sql: String) async throws -> QueryResultSet
    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet
    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet
    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo]
    func listDatabases() async throws -> [String]
    func listSchemas() async throws -> [String]
    func listExtensions() async throws -> [SchemaObjectInfo]
    func listExtensionObjects(extensionName: String) async throws -> [ExtensionObjectInfo]
    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet
    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo]
    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String
    func executeUpdate(_ sql: String) async throws -> Int
    func renameTable(schema: String?, oldName: String, newName: String) async throws
    func dropTable(schema: String?, name: String, ifExists: Bool) async throws
    func truncateTable(schema: String?, name: String) async throws
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails
    func dropIndex(schema: String, name: String) async throws
    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult
    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult
    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws
    func analyzeTable(schema: String, table: String) async throws
    func reindexTable(schema: String, table: String) async throws
    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult
    func updateIndexStatistics(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult

    // MSSQL Maintenance
    func listFragmentedIndexes() async throws -> [SQLServerIndexFragmentation]
    func getDatabaseHealth() async throws -> SQLServerDatabaseHealth
    func getBackupHistory(limit: Int) async throws -> [SQLServerBackupHistoryEntry]
    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult
    func shrinkDatabase() async throws -> DatabaseMaintenanceResult

    func sessionForDatabase(_ database: String) async throws -> DatabaseSession
    func currentDatabaseName() async throws -> String?
    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring
}

protocol DatabaseFactory: Sendable {
    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        trustServerCertificate: Bool,
        tlsMode: TLSMode,
        sslRootCertPath: String?,
        sslCertPath: String?,
        sslKeyPath: String?,
        mssqlEncryptionMode: MSSQLEncryptionMode,
        readOnlyIntent: Bool,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int
    ) async throws -> DatabaseSession
}

public protocol DatabaseMetadataSession: DatabaseSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo

    func listAvailableExtensions() async throws -> [AvailableExtensionInfo]
    func installExtension(name: String, schema: String?, version: String?, cascade: Bool) async throws
    func updateExtension(name: String, to version: String?) async throws
    func dropExtension(name: String, cascade: Bool) async throws
}

public extension DatabaseMetadataSession {
    func listAvailableExtensions() async throws -> [AvailableExtensionInfo] {
        []
    }

    func installExtension(name: String, schema: String?, version: String?, cascade: Bool) async throws {
        throw DatabaseError.queryError("Extensions are not supported for this database type")
    }

    func updateExtension(name: String, to version: String?) async throws {
        throw DatabaseError.queryError("Extensions are not supported for this database type")
    }

    func dropExtension(name: String, cascade: Bool) async throws {
        throw DatabaseError.queryError("Extensions are not supported for this database type")
    }
}

public protocol DatabaseSchemaSummaryProviding: AnyObject {
    func loadSchemaSummary(_ schemaName: String) async throws -> SchemaInfo
}

public extension DatabaseSession {
    func isSuperuser() async throws -> Bool {
        false
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: progressHandler)
    }

    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Index rebuild is not supported for this database type")
    }

    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Index rebuild is not supported for this database type")
    }

    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Update statistics is not supported for this database type")
    }

    func updateIndexStatistics(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Update statistics is not supported for this database type")
    }

    func dropIndex(schema: String, name: String) async throws {
        throw DatabaseError.queryError("Drop index is not supported for this database type")
    }

    func renameTable(schema: String?, oldName: String, newName: String) async throws {
        throw DatabaseError.queryError("Table rename is not supported for this database type")
    }

    func dropTable(schema: String?, name: String, ifExists: Bool) async throws {
        throw DatabaseError.queryError("Table drop is not supported for this database type")
    }

    func truncateTable(schema: String?, name: String) async throws {
        throw DatabaseError.queryError("Table truncate is not supported for this database type")
    }

    func listExtensions() async throws -> [SchemaObjectInfo] {
        []
    }

    func listExtensionObjects(extensionName: String) async throws -> [ExtensionObjectInfo] {
        []
    }

    func listFragmentedIndexes() async throws -> [SQLServerIndexFragmentation] {
        []
    }

    func getDatabaseHealth() async throws -> SQLServerDatabaseHealth {
        throw DatabaseError.queryError("Database health stats are not supported for this database type")
    }

    func getBackupHistory(limit: Int) async throws -> [SQLServerBackupHistoryEntry] {
        []
    }

    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Integrity checks are not supported for this database type")
    }

    func shrinkDatabase() async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Shrink database is not supported for this database type")
    }

    /// Returns a session connected to the specified database.
    /// The default returns `self` — works for engines that support `USE database` (e.g. SQL Server).
    /// PostgreSQL overrides this to vend a connection via `PostgresServerConnection`.
    func sessionForDatabase(_ database: String) async throws -> DatabaseSession {
        self
    }

    func currentDatabaseName() async throws -> String? {
        nil
    }

    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring {
        throw DatabaseError.queryError("Activity monitor is not supported for this database type")
    }

    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws {
        throw DatabaseError.queryError("VACUUM is not supported for this database type")
    }

    func analyzeTable(schema: String, table: String) async throws {
        throw DatabaseError.queryError("ANALYZE is not supported for this database type")
    }

    func reindexTable(schema: String, table: String) async throws {
        throw DatabaseError.queryError("REINDEX is not supported for this database type")
    }
}

protocol ExecutionPlanProviding: DatabaseSession {
    func getEstimatedExecutionPlan(_ sql: String) async throws -> ExecutionPlanData
    func getActualExecutionPlan(_ sql: String) async throws -> (result: QueryResultSet, plan: ExecutionPlanData)
}

/// A database session that supports reading and modifying extended properties (SQL Server only).
protocol ExtendedPropertiesProviding: DatabaseSession {
    func listExtendedProperties(schema: String, objectType: String, objectName: String, childType: String?, childName: String?) async throws -> [ExtendedPropertyInfo]
    func listExtendedPropertiesForAllColumns(schema: String, table: String) async throws -> [String: [ExtendedPropertyInfo]]
    func addExtendedProperty(name: String, value: String, schema: String, objectType: String, objectName: String, childType: String?, childName: String?) async throws
    func updateExtendedProperty(name: String, value: String, schema: String, objectType: String, objectName: String, childType: String?, childName: String?) async throws
    func dropExtendedProperty(name: String, schema: String, objectType: String, objectName: String, childType: String?, childName: String?) async throws
}

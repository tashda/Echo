import Foundation
import SQLServerKit

public protocol DatabaseSession: Sendable {
    func close() async
    func isSuperuser() async throws -> Bool
    func fetchPermissions() async throws -> (any DatabasePermissionProviding)?
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
    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType, database: String?) async throws -> String
    func executeUpdate(_ sql: String) async throws -> Int
    func executeUpdatesAtomically(_ statements: [String]) async throws
    func renameTable(schema: String?, oldName: String, newName: String) async throws
    func dropTable(schema: String?, name: String, ifExists: Bool) async throws
    func truncateTable(schema: String?, name: String) async throws
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails
    func dropIndex(schema: String, name: String) async throws
    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult
    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult
    func reorganizeIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult
    func reorganizeIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult
    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws
    func analyzeTable(schema: String, table: String) async throws
    func reindexTable(schema: String, table: String) async throws
    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult
    func updateIndexStatistics(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult

    // MSSQL Maintenance
    func listTableStats() async throws -> [SQLServerTableStat]
    func checkTable(schema: String, table: String) async throws -> DatabaseMaintenanceResult
    func rebuildTable(schema: String, table: String) async throws -> DatabaseMaintenanceResult
    func listFragmentedIndexes() async throws -> [SQLServerIndexFragmentation]
    func getDatabaseHealth() async throws -> SQLServerDatabaseHealth
    func getBackupHistory(limit: Int) async throws -> [SQLServerBackupHistoryEntry]
    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult
    func shrinkDatabase() async throws -> DatabaseMaintenanceResult
    func shrinkDatabase(targetPercent: Int, truncateOnly: Bool) async throws -> DatabaseMaintenanceResult
    func shrinkFile(fileName: String, targetSizeMB: Int) async throws -> DatabaseMaintenanceResult
    func listDatabaseFiles() async throws -> [SQLServerDatabaseFile]

    func detachDatabase(name: String, skipChecks: Bool) async throws
    func attachDatabase(name: String, files: [String]) async throws
    func listDatabaseSnapshots() async throws -> [SQLServerDatabaseSnapshot]
    func createDatabaseSnapshot(name: String, sourceDatabase: String) async throws
    func deleteDatabaseSnapshot(name: String) async throws
    func revertToSnapshot(snapshotName: String) async throws

    func sessionForDatabase(_ database: String) async throws -> DatabaseSession
    func currentDatabaseName() async throws -> String?
    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring

    // Performance & Diagnostics
    var tuning: SQLServerTuningClient? { get }
    var profiler: SQLServerProfilerClient? { get }
    var resourceGovernor: SQLServerResourceGovernorClient? { get }
    var policy: SQLServerPolicyClient? { get }
    var dependencies: SQLServerDependencyClient? { get }
    var dac: SQLServerDACClient? { get }
    var bulk: SQLServerBulkClient? { get }
    var ssis: SQLServerSSISClient? { get }

    // Multi-batch execution (GO batch separator support)
    func executeBatches(_ batches: [String], progressHandler: BatchProgressHandler?) async throws -> [BatchResult]

    /// Checks whether the connection to the database is still alive.
    /// Returns `true` if a lightweight query succeeds, `false` otherwise.
    func connectionIsAlive() async -> Bool
}

// Default for callers that don't need to specify a database
public extension DatabaseSession {
    func connectionIsAlive() async -> Bool {
        do {
            _ = try await simpleQuery("SELECT 1")
            return true
        } catch {
            return false
        }
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        try await getObjectDefinition(objectName: objectName, schemaName: schemaName, objectType: objectType, database: nil)
    }
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

    func fetchPermissions() async throws -> (any DatabasePermissionProviding)? {
        nil
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: progressHandler)
    }

    func executeUpdatesAtomically(_ statements: [String]) async throws {
        for statement in statements {
            _ = try await executeUpdate(statement)
        }
    }

    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Index rebuild is not supported for this database type")
    }

    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Index rebuild is not supported for this database type")
    }

    func reorganizeIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Index reorganize is not supported for this database type")
    }

    func reorganizeIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Index reorganize is not supported for this database type")
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

    func listTableStats() async throws -> [SQLServerTableStat] {
        []
    }

    func checkTable(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Table check is not supported for this database type")
    }

    func rebuildTable(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Heap rebuild is not supported for this database type")
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

    func shrinkDatabase(targetPercent: Int, truncateOnly: Bool) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Shrink database with options is not supported for this database type")
    }

    func shrinkFile(fileName: String, targetSizeMB: Int) async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Shrink file is not supported for this database type")
    }

    func listDatabaseFiles() async throws -> [SQLServerDatabaseFile] {
        []
    }

    func detachDatabase(name: String, skipChecks: Bool) async throws {
        throw DatabaseError.queryError("Detach database is not supported for this database type")
    }

    func attachDatabase(name: String, files: [String]) async throws {
        throw DatabaseError.queryError("Attach database is not supported for this database type")
    }

    func listDatabaseSnapshots() async throws -> [SQLServerDatabaseSnapshot] {
        []
    }

    func createDatabaseSnapshot(name: String, sourceDatabase: String) async throws {
        throw DatabaseError.queryError("Database snapshots are not supported for this database type")
    }

    func deleteDatabaseSnapshot(name: String) async throws {
        throw DatabaseError.queryError("Database snapshots are not supported for this database type")
    }

    func revertToSnapshot(snapshotName: String) async throws {
        throw DatabaseError.queryError("Database snapshots are not supported for this database type")
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

    var tuning: SQLServerTuningClient? { nil }
    var profiler: SQLServerProfilerClient? { nil }
    var resourceGovernor: SQLServerResourceGovernorClient? { nil }
    var policy: SQLServerPolicyClient? { nil }
    var dependencies: SQLServerDependencyClient? { nil }
    var dac: SQLServerDACClient? { nil }
    var bulk: SQLServerBulkClient? { nil }
    var ssis: SQLServerSSISClient? { nil }

    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws {
        throw DatabaseError.queryError("VACUUM is not supported for this database type")
    }

    func analyzeTable(schema: String, table: String) async throws {
        throw DatabaseError.queryError("ANALYZE is not supported for this database type")
    }

    func reindexTable(schema: String, table: String) async throws {
        throw DatabaseError.queryError("REINDEX is not supported for this database type")
    }

    func executeBatches(_ batches: [String], progressHandler: BatchProgressHandler?) async throws -> [BatchResult] {
        throw DatabaseError.queryError("Batch execution is not supported for this database type")
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

import Foundation
import SQLServerKit
import OSLog

/// Serializes metadata trace file writes to avoid data races
private actor MetadataTraceWriter {
    func append(_ data: Data, to path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// Adapter to make SQLServerClient conform to Echo's DatabaseSession protocol
nonisolated final class SQLServerSessionAdapter: DatabaseSession, MSSQLSession {
    let client: SQLServerClient
    private let configuration: SQLServerClient.Configuration
    nonisolated(unsafe) private(set) var database: String?
    let logger = Logger.mssql
    let metadataTraceEnabled = ProcessInfo.processInfo.environment["MSSQL_METADATA_TRACE"] == "1"
    let metadataTracePath: String?
    private static let traceWriter = MetadataTraceWriter()

    init(
        client: SQLServerClient,
        configuration: SQLServerClient.Configuration,
        database: String?
    ) {
        self.client = client
        self.configuration = configuration
        self.database = database
        if metadataTraceEnabled {
            let envPath = ProcessInfo.processInfo.environment["MSSQL_METADATA_TRACE_PATH"]
            metadataTracePath = envPath?.isEmpty == false ? envPath : "/tmp/echo-mssql-metadata-trace.log"
        } else {
            metadataTracePath = nil
        }
    }

    func close() async {
        do {
            try await client.close()
        } catch {
            // Ignore shutdown errors; the app is shutting down the session.
        }
    }

    func metadataTrace(_ line: String) {
        guard metadataTraceEnabled else { return }
        logger.info("\(line)")
        guard let path = metadataTracePath else { return }
        let payload = line + "\n"
        guard let data = payload.data(using: .utf8) else { return }
        Task {
            await Self.traceWriter.append(data, to: path)
        }
    }

    func metadataTimed<T>(_ label: String, operation: () async throws -> T) async throws -> T {
        guard metadataTraceEnabled else {
            return try await operation()
        }
        let started = Date()
        let result = try await operation()
        let elapsed = String(format: "%.3f", Date().timeIntervalSince(started))
        metadataTrace("[MSSQLMetadataTrace] step \(label) \(elapsed)s")
        return result
    }

    // MARK: - MSSQLSession

    func serverVersion() async throws -> String {
        try await client.serverVersion()
    }

    var metadata: SQLServerMetadataNamespace { client.metadata }
    var agent: SQLServerAgentOperations { client.agent }
    var admin: SQLServerAdministrationClient { client.admin }
    var security: SQLServerSecurityClient { client.security }
    var serverSecurity: SQLServerServerSecurityClient { client.serverSecurity }
    var extendedProperties: SQLServerExtendedPropertiesClient { client.extendedProperties }
    var queryStore: SQLServerQueryStoreClient { client.queryStore }
    var backupRestore: SQLServerBackupRestoreClient { client.backupRestore }
    var linkedServers: SQLServerLinkedServersClient { client.linkedServers }
    var extendedEvents: SQLServerExtendedEventsClient { client.extendedEvents }
    var availabilityGroups: SQLServerAvailabilityGroupsClient { client.availabilityGroups }
    var databaseMail: SQLServerDatabaseMailClient { client.databaseMail }
    var changeTracking: SQLServerChangeTrackingClient { client.changeTracking }
    var fullText: SQLServerFullTextClient { client.fullText }
    var maintenance: SQLServerMaintenanceClient { client.maintenance }
    var replication: SQLServerReplicationClient { client.replication }
    var cms: SQLServerCMSClient { client.cms }
    var errorLog: SQLServerErrorLogClient { client.errorLog }
    var audit: SQLServerAuditClient { client.audit }
    var alwaysEncrypted: SQLServerAlwaysEncryptedClient { client.alwaysEncrypted }
    var triggers: SQLServerTriggerClient { client.triggers }
    var temporal: SQLServerTemporalClient { client.temporal }
    var serviceBroker: SQLServerServiceBrokerClient { client.serviceBroker }
    var polyBase: SQLServerPolyBaseClient { client.polyBase }
    var tuning: SQLServerTuningClient { client.tuning }
    var profiler: SQLServerProfilerClient { client.profiler }
    var resourceGovernor: SQLServerResourceGovernorClient { client.resourceGovernor }
    var policy: SQLServerPolicyClient { client.policy }
    var dependencies: SQLServerDependencyClient { client.dependencies }
    var dac: SQLServerDACClient { client.dac }
    var bulkCopy: SQLServerBulkCopyClient { SQLServerBulkCopyClient(client: client) }
    var ssis: SQLServerSSISClient { client.ssis }
    var ssas: SQLServerSSASClient { client.ssas }
    var ssrs: SQLServerSSRSClient { client.ssrs }

    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        let nioResult = try await client.maintenance.rebuildIndex(schema: schema, table: table, name: index)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        let nioResult = try await client.maintenance.rebuildIndexes(schema: schema, table: table)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func reorganizeIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        let nioResult = try await client.maintenance.reorganizeIndex(schema: schema, table: table, name: index)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func reorganizeIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        let nioResult = try await client.maintenance.reorganizeIndexes(schema: schema, table: table)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws {
        throw DatabaseError.queryError("VACUUM is not supported for SQL Server")
    }

    func analyzeTable(schema: String, table: String) async throws {
        throw DatabaseError.queryError("ANALYZE is not supported for SQL Server")
    }

    func reindexTable(schema: String, table: String) async throws {
        throw DatabaseError.queryError("Use rebuildIndex for SQL Server")
    }

    func listTableStats() async throws -> [SQLServerTableStat] {
        let nioStats = try await client.maintenance.listTableStats()
        return nioStats.map { stat in
            let lastUpdate: Date? = stat.lastStatsUpdate.flatMap { ISO8601DateFormatter().date(from: $0) }
            return SQLServerTableStat(
                schemaName: stat.schemaName,
                tableName: stat.tableName,
                tableType: stat.tableType,
                rowCount: stat.rowCount,
                dataSpaceKB: stat.dataSpaceKB,
                indexSpaceKB: stat.indexSpaceKB,
                unusedSpaceKB: stat.unusedSpaceKB,
                totalSpaceKB: stat.totalSpaceKB,
                lastStatsUpdate: lastUpdate,
                forwardedRecords: nil
            )
        }
    }

    func checkTable(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        do {
            let messages = try await client.maintenance.checkTable(schema: schema, table: table)
            let messageTexts = messages.map(\.message)
            return DatabaseMaintenanceResult(
                operation: "Check Table",
                messages: messageTexts.isEmpty ? ["CHECKTABLE found 0 allocation errors and 0 consistency errors."] : messageTexts,
                succeeded: true
            )
        } catch {
            return DatabaseMaintenanceResult(operation: "Check Table", messages: [error.localizedDescription], succeeded: false)
        }
    }

    func rebuildTable(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        do {
            let messages = try await client.maintenance.rebuildTable(schema: schema, table: table)
            let messageTexts = messages.map(\.message)
            return DatabaseMaintenanceResult(
                operation: "Rebuild Table",
                messages: messageTexts.isEmpty ? ["Table rebuilt successfully."] : messageTexts,
                succeeded: true
            )
        } catch {
            return DatabaseMaintenanceResult(operation: "Rebuild Table", messages: [error.localizedDescription], succeeded: false)
        }
    }

    func listFragmentedIndexes() async throws -> [SQLServerIndexFragmentation] {
        let nioStats = try await client.indexes.listFragmentedIndexes()
        return nioStats.map { stat in
            SQLServerIndexFragmentation(
                schemaName: stat.schemaName,
                tableName: stat.tableName,
                indexName: stat.indexName,
                fragmentationPercent: stat.fragmentationPercent,
                pageCount: stat.pageCount,
                indexType: stat.indexType,
                indexId: stat.indexId,
                isUnique: stat.isUnique,
                isPrimaryKey: stat.isPrimaryKey,
                totalScans: stat.totalScans,
                totalUpdates: stat.totalUpdates,
                sizeKB: stat.sizeKB,
                tableSizeKB: stat.tableSizeKB,
                lastStatsUpdate: stat.lastStatsUpdate
            )
        }
    }

    func getDatabaseHealth() async throws -> SQLServerDatabaseHealth {
        let health = try await client.maintenance.getDatabaseHealth()
        return SQLServerDatabaseHealth(
            name: health.name,
            owner: health.owner,
            createDate: health.createDate,
            sizeMB: health.sizeMB,
            recoveryModel: health.recoveryModel,
            status: health.status,
            compatibilityLevel: health.compatibilityLevel,
            collationName: health.collationName
        )
    }

    func getBackupHistory(limit: Int) async throws -> [SQLServerBackupHistoryEntry] {
        guard let dbName = try await currentDatabaseName() else { return [] }
        let history = try await client.backupRestore.getBackupHistory(database: dbName, limit: limit)
        return history.map { entry in
            SQLServerBackupHistoryEntry(
                id: entry.id,
                name: entry.name,
                description: entry.description,
                startDate: entry.startDate,
                finishDate: entry.finishDate,
                type: entry.type,
                size: entry.size,
                compressedSize: entry.compressedSize,
                physicalPath: entry.physicalPath,
                serverName: entry.serverName,
                recoveryModel: entry.recoveryModel
            )
        }
    }

    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult {
        guard let dbName = try await currentDatabaseName() else { 
            return DatabaseMaintenanceResult(operation: "Check Database", messages: ["No active database context"], succeeded: false)
        }
        let nioResult = try await client.maintenance.checkDatabase(database: dbName)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func shrinkDatabase() async throws -> DatabaseMaintenanceResult {
        guard let dbName = try await currentDatabaseName() else {
            return DatabaseMaintenanceResult(operation: "Shrink Database", messages: ["No active database context"], succeeded: false)
        }
        let nioResult = try await client.maintenance.shrinkDatabase(database: dbName)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func shrinkDatabase(targetPercent: Int, truncateOnly: Bool) async throws -> DatabaseMaintenanceResult {
        guard let dbName = try await currentDatabaseName() else {
            return DatabaseMaintenanceResult(operation: "Shrink Database", messages: ["No active database context"], succeeded: false)
        }
        let option: SQLServerShrinkOption = truncateOnly ? .truncateOnly : .defaultBehavior
        let nioResult = try await client.maintenance.shrinkDatabase(database: dbName, targetPercent: targetPercent, option: option)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func shrinkFile(fileName: String, targetSizeMB: Int) async throws -> DatabaseMaintenanceResult {
        guard let dbName = try await currentDatabaseName() else {
            return DatabaseMaintenanceResult(operation: "Shrink File", messages: ["No active database context"], succeeded: false)
        }
        let nioResult = try await client.maintenance.shrinkFile(database: dbName, fileName: fileName, targetSizeMB: targetSizeMB)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func listDatabaseFiles() async throws -> [SQLServerDatabaseFile] {
        guard let dbName = try await currentDatabaseName() else { return [] }
        return try await client.admin.getDatabaseFiles(name: dbName)
    }

    func detachDatabase(name: String, skipChecks: Bool) async throws {
        _ = try await client.admin.detachDatabase(name: name, skipChecks: skipChecks)
    }

    func attachDatabase(name: String, files: [String]) async throws {
        _ = try await client.admin.attachDatabase(name: name, files: files)
    }

    func listDatabaseSnapshots() async throws -> [SQLServerDatabaseSnapshot] {
        try await client.admin.listSnapshots()
    }

    func createDatabaseSnapshot(name: String, sourceDatabase: String) async throws {
        _ = try await client.admin.createSnapshot(name: name, sourceDatabase: sourceDatabase)
    }

    func deleteDatabaseSnapshot(name: String) async throws {
        _ = try await client.admin.dropSnapshot(name: name)
    }

    func revertToSnapshot(snapshotName: String) async throws {
        _ = try await client.admin.revertToSnapshot(snapshotName: snapshotName)
    }

    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        let nioResult = try await client.maintenance.updateStatistics(schema: schema, table: table)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func updateIndexStatistics(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        let nioResult = try await client.maintenance.updateIndexStatistics(schema: schema, table: table, index: index)
        return DatabaseMaintenanceResult(operation: nioResult.operation, messages: nioResult.messages, succeeded: nioResult.succeeded)
    }

    func sessionForDatabase(_ database: String) async throws -> DatabaseSession {
        let trimmedDatabase = database.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDatabase.isEmpty else {
            return self
        }

        if self.database?.caseInsensitiveCompare(trimmedDatabase) == .orderedSame {
            return self
        }

        var databaseConfiguration = configuration
        databaseConfiguration.connection.login.database = trimmedDatabase
        let databaseClient = try await SQLServerClient.connect(configuration: databaseConfiguration)
        return SQLServerSessionAdapter(
            client: databaseClient,
            configuration: databaseConfiguration,
            database: trimmedDatabase
        )
    }

    func currentDatabaseName() async throws -> String? {
        try await client.currentDatabaseName()
    }

    func isSuperuser() async throws -> Bool {
        try await client.serverSecurity.isMemberOf(role: "sysadmin")
    }

    func fetchPermissions() async throws -> (any DatabasePermissionProviding)? {
        let perms = try await client.metadata.checkServerPermissions()
        return MSSQLPermissionAdapter(permissions: perms)
    }

    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring {
        SQLServerActivityMonitorWrapper(client.activity)
    }
}

import Foundation
import SQLServerKit
import OSLog

nonisolated final class MSSQLDedicatedQuerySession: DatabaseSession, MSSQLSession, @unchecked Sendable {
    /// Guards `connection` and `reconnectTask`, which several tasks of the
    /// tab can reach (a run, a cancel, the explorer asking for the database).
    private let lock = NSLock()
    private var _connection: SQLServerConnection
    private let connectionConfiguration: SQLServerConnection.Configuration
    private var reconnectTask: Task<SQLServerConnection, Error>?
    let metadataSession: SQLServerSessionAdapter
    let logger = Logger.query

    init(
        connection: SQLServerConnection,
        configuration: SQLServerConnection.Configuration,
        metadataSession: SQLServerSessionAdapter
    ) {
        self._connection = connection
        self.connectionConfiguration = configuration
        self.metadataSession = metadataSession
    }

    private var connection: SQLServerConnection {
        lock.withLock { _connection }
    }

    var database: String? {
        connection.currentDatabase
    }

    func close() async {
        let (current, pending) = lock.withLock { () -> (SQLServerConnection, Task<SQLServerConnection, Error>?) in
            let pending = reconnectTask
            reconnectTask = nil
            return (_connection, pending)
        }
        pending?.cancel()
        do {
            try await current.close()
        } catch {
            logger.debug("Dedicated query connection close failed: \(error.localizedDescription)")
        }
    }

    func serverVersion() async throws -> String {
        let connection = try await readyConnection()
        return try await connection.serverVersion()
    }

    /// The tab's connection. A connection that has closed (the server or the
    /// network dropped it) is replaced by a new session first; the old
    /// session's temporary tables, SET options and transaction are gone.
    func readyConnection() async throws -> SQLServerConnection {
        let task: Task<SQLServerConnection, Error>? = lock.withLock {
            if let reconnectTask { return reconnectTask }
            guard _connection.isClosed else { return nil }
            return startReconnectLocked()
        }
        guard let task else { return connection }
        let reconnected = try await task.value
        lock.withLock {
            _connection = reconnected
            reconnectTask = nil
        }
        return reconnected
    }

    /// Called after a cancelled run. The driver cancels the statement on the
    /// server and keeps the session (round 22, cancel keeps the session), so
    /// a new session is started only if the connection did not survive.
    func reconnectAfterCancellation() {
        lock.withLock {
            guard reconnectTask == nil, _connection.isClosed else { return }
            _ = startReconnectLocked()
        }
    }

    private func startReconnectLocked() -> Task<SQLServerConnection, Error> {
        let previous = _connection
        let configuration = connectionConfiguration
        let targetDatabase = previous.currentDatabase
        let task = Task { [logger] () throws -> SQLServerConnection in
            do {
                try await previous.close()
            } catch {
                logger.debug("Closing the dropped connection before reconnecting failed: \(error.localizedDescription)")
            }
            let newConnection = try await SQLServerConnection.connect(configuration: configuration)
            if !targetDatabase.isEmpty,
               newConnection.currentDatabase.caseInsensitiveCompare(targetDatabase) != .orderedSame {
                try await newConnection.changeDatabase(targetDatabase)
            }
            return newConnection
        }
        reconnectTask = task
        return task
    }

    var metadata: SQLServerMetadataNamespace { metadataSession.metadata }
    var agent: SQLServerAgentOperations { metadataSession.agent }
    var admin: SQLServerAdministrationClient { metadataSession.admin }
    var security: SQLServerSecurityClient { metadataSession.security }
    var serverSecurity: SQLServerServerSecurityClient { metadataSession.serverSecurity }
    var extendedProperties: SQLServerExtendedPropertiesClient { metadataSession.extendedProperties }
    var queryStore: SQLServerQueryStoreClient { metadataSession.queryStore }
    var backupRestore: SQLServerBackupRestoreClient { metadataSession.backupRestore }
    var linkedServers: SQLServerLinkedServersClient { metadataSession.linkedServers }
    var extendedEvents: SQLServerExtendedEventsClient { metadataSession.extendedEvents }
    var availabilityGroups: SQLServerAvailabilityGroupsClient { metadataSession.availabilityGroups }
    var databaseMail: SQLServerDatabaseMailClient { metadataSession.databaseMail }
    var changeTracking: SQLServerChangeTrackingClient { metadataSession.changeTracking }
    var fullText: SQLServerFullTextClient { metadataSession.fullText }
    var maintenance: SQLServerMaintenanceClient { metadataSession.maintenance }
    var replication: SQLServerReplicationClient { metadataSession.replication }
    var cms: SQLServerCMSClient { metadataSession.cms }
    var errorLog: SQLServerErrorLogClient { metadataSession.errorLog }
    var audit: SQLServerAuditClient { metadataSession.audit }
    var alwaysEncrypted: SQLServerAlwaysEncryptedClient { metadataSession.alwaysEncrypted }
    var triggers: SQLServerTriggerClient { metadataSession.triggers }
    var temporal: SQLServerTemporalClient { metadataSession.temporal }
    var serviceBroker: SQLServerServiceBrokerClient { metadataSession.serviceBroker }
    var polyBase: SQLServerPolyBaseClient { metadataSession.polyBase }
    var tuning: SQLServerTuningClient { metadataSession.tuning }
    var profiler: SQLServerProfilerClient { metadataSession.profiler }
    var resourceGovernor: SQLServerResourceGovernorClient { metadataSession.resourceGovernor }
    var policy: SQLServerPolicyClient { metadataSession.policy }
    @available(*, deprecated)
    var dependencies: SQLServerDependencyClient { metadataSession.dependencies }
    @available(*, deprecated)
    var dac: SQLServerDACClient { metadataSession.dac }
    var bulk: SQLServerBulkClient { metadataSession.bulk! }
    var ssis: SQLServerSSISClient { metadataSession.ssis }
}

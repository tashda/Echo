import EchoSense
import Foundation
import NIOCore
import SQLServerKit
import OSLog

nonisolated final class MSSQLDedicatedQuerySession: DatabaseSession, MSSQLSession, @unchecked Sendable {
    /// A dropped connection: the database, whether its transaction was lost, and whether this is a
    /// reminder (a run was attempted while waiting for Reconnect) rather than the drop itself.
    typealias ConnectionLostHandler = @Sendable (_ database: String, _ transactionLost: Bool, _ isReminder: Bool) -> Void

    /// Guards the mutable state below, which several tasks of the tab can reach
    /// (a run, a cancel, the explorer asking for the database, a drop).
    private let lock = NSLock()
    private var _connection: SQLServerConnection
    private let connectionConfiguration: SQLServerConnection.Configuration
    private var reconnectTask: Task<SQLServerConnection, Error>?
    private var connectionLostHandler: ConnectionLostHandler?
    /// Connections Echo closed on purpose (tab closed, Force Stop, replaced); their close is not a drop.
    private var closingOnPurpose: Set<Swift.ObjectIdentifier> = []
    /// Set when the connection dropped with a transaction open (round 22, LC4 = Postgres RC2):
    /// runs wait for ``reconnect()`` instead of silently starting a new session.
    private var awaitingReconnectDatabase: String?
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
        watch(connection)
    }

    private var connection: SQLServerConnection {
        lock.withLock { _connection }
    }

    /// Whether the session has an open transaction. The driver follows SQL Server's transaction
    /// notices (ENVCHANGE), so this costs no round trip.
    var isInTransaction: Bool {
        connection.isInTransaction
    }

    var database: String? {
        connection.currentDatabase
    }

    func close() async {
        let (current, pending) = lock.withLock { () -> (SQLServerConnection, Task<SQLServerConnection, Error>?) in
            let pending = reconnectTask
            reconnectTask = nil
            connectionLostHandler = nil
            closingOnPurpose.insert(Swift.ObjectIdentifier(_connection))
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
        enum Next { case current, wait(Task<SQLServerConnection, Error>), refuse(String, ConnectionLostHandler?) }
        let next: Next = lock.withLock {
            if let reconnectTask { return .wait(reconnectTask) }
            if let database = awaitingReconnectDatabase { return .refuse(database, connectionLostHandler) }
            guard _connection.isClosed else { return .current }
            return .wait(startReconnectLocked())
        }
        switch next {
        case .current:
            return connection
        case .refuse(let database, let handler):
            // A run while waiting for Reconnect brings the notification (and its button) back.
            handler?(database, true, true)
            throw MSSQLSessionError.awaitingReconnect(database: database)
        case .wait(let task):
            return try await finishReconnect(task)
        }
    }

    /// The Reconnect button: a new session in the tab's database. SET options, temporary tables
    /// and the lost transaction are gone.
    func reconnect() async throws {
        let task: Task<SQLServerConnection, Error> = lock.withLock {
            awaitingReconnectDatabase = nil
            return reconnectTask ?? startReconnectLocked()
        }
        _ = try await finishReconnect(task)
    }

    /// Whether the connection dropped with a transaction open and runs wait for ``reconnect()``.
    var isAwaitingReconnect: Bool {
        lock.withLock { awaitingReconnectDatabase != nil }
    }

    /// Tells `handler` the moment the tab's connection drops (round 22, LC4 = Postgres CW2).
    func setConnectionLostHandler(_ handler: ConnectionLostHandler?) {
        lock.withLock { connectionLostHandler = handler }
    }

    /// Force Stop (round 21 cancel, CS2, for SQL Server): closes the connection that is still
    /// running a statement. The server rolls back an open transaction; the next run starts a new
    /// session quietly, because the user asked for this.
    func forceStopRunningQuery() async -> (stopped: Bool, transactionWasOpen: Bool) {
        let current = lock.withLock { () -> SQLServerConnection in
            closingOnPurpose.insert(Swift.ObjectIdentifier(_connection))
            return _connection
        }
        guard !current.isClosed else { return (false, false) }
        let transactionWasOpen = current.isInTransaction
        try? await current.close()
        return (true, transactionWasOpen)
    }

    private func finishReconnect(_ task: Task<SQLServerConnection, Error>) async throws -> SQLServerConnection {
        let reconnected = try await task.value
        let isNew = lock.withLock { () -> Bool in
            let isNew = _connection !== reconnected
            _connection = reconnected
            reconnectTask = nil
            return isNew
        }
        if isNew { watch(reconnected) }
        return reconnected
    }

    // MARK: - Drops

    private func watch(_ connection: SQLServerConnection) {
        connection.closeFuture.whenComplete { [weak self] _ in
            self?.connectionDidClose(connection)
        }
    }

    private func connectionDidClose(_ closed: SQLServerConnection) {
        let report: (ConnectionLostHandler, String, Bool)? = lock.withLock {
            if closingOnPurpose.remove(Swift.ObjectIdentifier(closed)) != nil { return nil }
            guard closed === _connection, reconnectTask == nil else { return nil }
            // The driver keeps the transaction flag after the close: SQL Server rolls an open
            // transaction back when its session ends.
            let database = closed.currentDatabase
            let transactionLost = closed.isInTransaction
            if transactionLost { awaitingReconnectDatabase = database }
            return connectionLostHandler.map { ($0, database, transactionLost) }
        }
        if let (handler, database, transactionLost) = report {
            handler(database, transactionLost, false)
        }
    }

    /// Runs one query of the tab. When it fails because the session is gone (round 22, FE1:
    /// severity 20 and above ends it, or the network dropped), the new session starts at once,
    /// so the next run does not reuse a connection whose socket has not finished closing.
    func runRecoveringLostConnection<T>(_ body: () async throws -> T) async throws -> T {
        let current = connection
        do {
            return try await body()
        } catch {
            if SQLServerFailure.isConnectionLost(error), !current.isClosed {
                // Finish closing it now: the drop is reported like any other (with or without a
                // lost transaction), and the next run reconnects or waits for Reconnect.
                try? await current.close()
            }
            throw error
        }
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
        if !previous.isClosed { closingOnPurpose.insert(Swift.ObjectIdentifier(previous)) }
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
    var scripts: SQLServerScriptClient { metadataSession.scripts }
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

/// Errors from a query tab's SQL Server session.
enum MSSQLSessionError: LocalizedError, Equatable {
    /// The connection dropped with a transaction open; runs wait for Reconnect.
    case awaitingReconnect(database: String)

    var errorDescription: String? {
        switch self {
        case .awaitingReconnect(let database):
            QueryConnectionLossText.awaitingReconnect(database: database)
        }
    }
}

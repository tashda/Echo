import EchoSense
import Foundation
import PostgresKit

/// One pinned (non-pooled) connection per database for a query tab.
///
/// A query tab must run every statement on the same backend, or `BEGIN … COMMIT`, `SET`, temporary
/// tables and `SET ROLE` silently stop working. This store hands out a `PostgresSessionConnection` per
/// database the tab uses and keeps it for the tab's lifetime.
///
/// It never reconnects silently after lost work (round 21, connection lost): it reports a drop the
/// moment it happens through the connection-lost handler. When a transaction was open, every run
/// fails with ``PostgresPinnedSessionError/awaitingReconnect(database:)`` until ``reconnect(database:)``
/// is called (the Reconnect button). When no transaction was open, the next run reconnects.
actor PostgresPinnedSessionStore {
    /// A dropped connection: the database, whether its transaction was lost, and whether this is a
    /// reminder (a run was attempted while waiting for Reconnect) rather than the drop itself.
    typealias ConnectionLostHandler = @Sendable (_ database: String, _ transactionLost: Bool, _ isReminder: Bool) -> Void

    private let serverConnection: PostgresServerConnection
    private var sessions: [String: PostgresSessionConnection] = [:]
    private var databaseNames: [String: String] = [:]
    /// Sessions this store closed on purpose; their close is not a drop.
    private var closing: Set<ObjectIdentifier> = []
    private var connectionLostHandler: ConnectionLostHandler?
    /// The tab's query time limit (round 21, timeouts): nil leaves the server's own, `.zero` is none.
    private var statementTimeout: Duration?
    private var appliedTimeouts: [ObjectIdentifier: Duration?] = [:]

    init(serverConnection: PostgresServerConnection) {
        self.serverConnection = serverConnection
    }

    func setConnectionLostHandler(_ handler: ConnectionLostHandler?) {
        connectionLostHandler = handler
    }

    func session(for database: String) async throws -> PostgresSessionConnection {
        let key = database.lowercased()
        if let existing = sessions[key] {
            if !existing.isClosed { return existing }
            if existing.transactionWasLost {
                let name = databaseNames[key] ?? database
                connectionLostHandler?(name, true, true)
                throw PostgresPinnedSessionError.awaitingReconnect(database: name)
            }
            sessions[key] = nil
        }
        let session = try await serverConnection.makeSession(database: database)
        sessions[key] = session
        databaseNames[key] = database
        watch(session, key: key)
        await applyStatementTimeout(to: session)
        return session
    }

    /// Sets the tab's query time limit for every session. A session gets `SET statement_timeout` only
    /// when its value changes, so runs normally cost nothing extra.
    func setStatementTimeout(_ timeout: Duration?) async {
        statementTimeout = timeout
        for session in sessions.values where !session.isClosed { await applyStatementTimeout(to: session) }
    }

    private func applyStatementTimeout(to session: PostgresSessionConnection) async {
        let id = ObjectIdentifier(session)
        let applied = appliedTimeouts[id] ?? nil
        guard applied != statementTimeout, !session.isQueryInFlight else { return }
        do {
            try await session.setStatementTimeout(statementTimeout)
            appliedTimeouts[id] = statementTimeout
        } catch {
            appliedTimeouts[id] = nil
        }
    }

    /// The server's own statement_timeout for `database` in seconds, when Echo set none (SL1).
    func serverStatementTimeout(for database: String) async -> TimeInterval? {
        guard let session = sessions[database.lowercased()], !session.isClosed,
              let result = try? await session.queryResult("SELECT current_setting('statement_timeout')"),
              let cell = result.rows.first?.first,
              let text = PostgresCellFormatter().stringValue(for: cell) else { return nil }
        return QueryTimeLimitStop.parseServerSetting(text)
    }

    /// The backend of the statement this tab is running, for the lock-wait check (LF3).
    func runningBackendPID() -> Int32? {
        sessions.values.first { !$0.isClosed && $0.isQueryInFlight }?.backendPID
    }

    /// Whether a connection dropped with a transaction open and is waiting for ``reconnect(database:)``.
    func isAwaitingReconnect() -> Bool {
        sessions.values.contains { $0.isClosed && $0.transactionWasLost }
    }

    /// Forgets every dropped connection and opens a new session for `database` (a new backend:
    /// `SET`, temporary tables and the lost transaction are gone).
    func reconnect(database: String) async throws {
        for (key, session) in sessions where session.isClosed { sessions[key] = nil }
        _ = try await self.session(for: database)
    }

    /// Cancels, on the server, every statement currently running on this tab's sessions.
    /// Returns whether a cancel was sent.
    func cancelRunning(using client: PostgresKit.PostgresClient) async -> Bool {
        var sent = false
        for session in sessions.values where session.isQueryInFlight {
            if (try? await session.cancel(using: client)) == true { sent = true }
        }
        return sent
    }

    /// Force Stop (round 21, cancel CS2): closes the connections still running a statement after a
    /// cancel the server did not answer. The next run opens a new session.
    func forceStopRunning() async -> (stopped: Bool, transactionWasOpen: Bool) {
        var stopped = false
        var transactionWasOpen = false
        for (key, session) in sessions where session.isQueryInFlight {
            closing.insert(ObjectIdentifier(session))
            if session.transactionStatus != .idle { transactionWasOpen = true }
            await session.close()
            sessions[key] = nil
            stopped = true
        }
        return (stopped, transactionWasOpen)
    }

    /// The transaction state of the session for `database`, if it is open.
    func transactionStatus(for database: String) -> PostgresTransactionStatus? {
        guard let session = sessions[database.lowercased()], !session.isClosed else { return nil }
        return session.transactionStatus
    }

    /// A transaction still open on one of this tab's sessions (round 21, open transaction on close).
    typealias OpenTransaction = QueryOpenTransaction

    /// The tab's open transactions, checked with the server (K1: a procedure may have committed or
    /// begun one without Echo seeing it). Two short queries per open session; only called before
    /// closing, switching, disconnecting or quitting.
    func openTransactions() async -> [OpenTransaction] {
        var open: [OpenTransaction] = []
        for (key, session) in sessions.sorted(by: { $0.key < $1.key }) where !session.isClosed {
            guard let status = try? await session.refreshTransactionStatus(), status != .idle else { continue }
            open.append(OpenTransaction(
                database: databaseNames[key] ?? key, failed: status == .failed,
                startedAt: session.transactionStartedAt, statements: session.statementsInTransaction
            ))
        }
        return open
    }

    /// Commits (or rolls back) every open transaction of the tab. A failed transaction is always
    /// rolled back; a COMMIT the server answers with ROLLBACK throws.
    func endTransactions(commit: Bool) async throws {
        for (key, session) in sessions where !session.isClosed && session.transactionStatus != .idle {
            let failed = session.transactionStatus == .failed
            let result = try await session.queryResult(commit && !failed ? "COMMIT" : "ROLLBACK")
            if commit, !failed, result.metadata.command == "ROLLBACK" {
                throw PostgresPinnedSessionError.commitRolledBack(database: databaseNames[key] ?? key)
            }
        }
    }

    /// Databases whose session is inside a transaction block.
    func databasesWithOpenTransaction() -> [String] {
        sessions.filter { !$0.value.isClosed && $0.value.transactionStatus != .idle }.map(\.key)
    }

    func closeAll() async {
        for session in sessions.values { closing.insert(ObjectIdentifier(session)) }
        for session in sessions.values { await session.close() }
        sessions.removeAll()
    }

    // MARK: - Drops

    private func watch(_ session: PostgresSessionConnection, key: String) {
        Task { [weak self] in
            await session.waitForClose()
            await self?.sessionDidClose(session, key: key)
        }
    }

    private func sessionDidClose(_ session: PostgresSessionConnection, key: String) {
        if closing.remove(ObjectIdentifier(session)) != nil { return }
        guard sessions[key] === session else { return }
        connectionLostHandler?(databaseNames[key] ?? key, session.transactionWasLost, false)
    }
}

/// Errors from ``PostgresPinnedSessionStore``.
enum PostgresPinnedSessionError: LocalizedError, Equatable {
    /// The connection dropped with a transaction open; runs wait for Reconnect.
    case awaitingReconnect(database: String)
    /// COMMIT answered ROLLBACK: the transaction had failed.
    case commitRolledBack(database: String)

    var errorDescription: String? {
        switch self {
        case .awaitingReconnect(let database):
            QueryConnectionLossText.awaitingReconnect(database: database)
        case .commitRolledBack(let database):
            "The transaction on \(database) could not be committed; the server rolled it back."
        }
    }
}

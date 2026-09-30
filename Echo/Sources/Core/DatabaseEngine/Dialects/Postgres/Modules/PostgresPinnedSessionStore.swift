import Foundation
import PostgresKit

/// One pinned (non-pooled) connection per database for a query tab.
///
/// A query tab must run every statement on the same backend, or `BEGIN … COMMIT`, `SET`, temporary
/// tables and `SET ROLE` silently stop working. This store hands out a `PostgresSessionConnection` per
/// database the tab uses and keeps it for the tab's lifetime. It never reconnects silently: if the
/// connection dropped while a transaction was open, the next run fails once with
/// `PostgresSessionError.connectionClosed(transactionLost: true)`, and the run after that reconnects.
actor PostgresPinnedSessionStore {
    private let serverConnection: PostgresServerConnection
    private var sessions: [String: PostgresSessionConnection] = [:]

    init(serverConnection: PostgresServerConnection) {
        self.serverConnection = serverConnection
    }

    func session(for database: String) async throws -> PostgresSessionConnection {
        let key = database.lowercased()
        if let existing = sessions[key] {
            if !existing.isClosed { return existing }
            sessions[key] = nil
            if existing.transactionWasLost {
                throw PostgresSessionError.connectionClosed(transactionLost: true)
            }
        }
        let session = try await serverConnection.makeSession(database: database)
        sessions[key] = session
        return session
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

    /// Databases whose session is inside a transaction block.
    func databasesWithOpenTransaction() -> [String] {
        sessions.filter { !$0.value.isClosed && $0.value.transactionStatus != .idle }.map(\.key)
    }

    func closeAll() async {
        for session in sessions.values { await session.close() }
        sessions.removeAll()
    }
}

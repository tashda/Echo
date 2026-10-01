import EchoSense
import Foundation
import MySQLKit
import Synchronization

/// A query tab's MySQL or MariaDB connection dropping, as for PostgreSQL and SQL Server (Echo Labs
/// round 21, connection lost; round 22, LC4): Echo is told within seconds, and with a transaction
/// open runs wait for Reconnect instead of silently running outside it.
extension MySQLSession {
    /// A dropped connection: the database, whether its transaction was lost, and whether this is a
    /// reminder (a run was attempted while waiting for Reconnect) rather than the drop itself.
    typealias ConnectionLostHandler = @Sendable (_ database: String, _ transactionLost: Bool, _ isReminder: Bool) -> Void

    var databaseName: String { defaultDatabase ?? configuration.database ?? "" }

    func setConnectionLostHandler(_ handler: ConnectionLostHandler?) {
        connectionLostHandler.withLock { $0 = handler }
    }

    /// Checks, without a round trip, whether the server or the network closed the connection, and
    /// tells the handler once.
    func checkConnection() async {
        guard let loss = await client.checkConnection() else { return }
        let handler = connectionLostHandler.withLock { $0 }
        handler?(databaseName, loss.transactionLost, false)
    }

    /// The Reconnect button: a new connection. Session settings, temporary tables and the lost
    /// transaction are gone.
    func reconnect() async throws {
        try await client.reconnect()
    }

    /// The error a failed run shows. A lost connection is reported at once; a run while waiting
    /// for Reconnect brings the notification (and its button) back.
    func queryFailure(_ error: any Error) async -> any Error {
        if case MySQLWireError.transactionLost = error {
            let handler = connectionLostHandler.withLock { $0 }
            handler?(databaseName, true, true)
            return MySQLSessionError.awaitingReconnect(database: databaseName)
        }
        if (error as? MySQLError)?.isConnectionLost == true { await checkConnection() }
        return DatabaseError.queryError(error.localizedDescription)
    }
}

/// Errors from a query tab's MySQL session.
enum MySQLSessionError: LocalizedError, Equatable {
    /// The connection dropped with a transaction open; runs wait for Reconnect.
    case awaitingReconnect(database: String)

    var errorDescription: String? {
        switch self {
        case .awaitingReconnect(let database):
            QueryConnectionLossText.awaitingReconnect(database: database)
        }
    }
}

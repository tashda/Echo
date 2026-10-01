import Foundation
import MySQLKit

/// Round 21's open-transaction alert for a MySQL or MariaDB tab (#57): the tab has one connection,
/// and the server reports an open transaction with every answer, so asking costs no round trip.
/// MySQL has no failed state: an error rolls back only its statement.
extension MySQLSession {
    func openTransactions(startedAt: Date?) async -> [QueryOpenTransaction] {
        guard await isInTransaction else { return [] }
        return [QueryOpenTransaction(database: databaseName, failed: false, startedAt: startedAt, statements: 0)]
    }

    func endTransactions(commit: Bool) async throws {
        if commit {
            try await client.transactions.commit()
        } else {
            try await client.transactions.rollback()
        }
    }
}

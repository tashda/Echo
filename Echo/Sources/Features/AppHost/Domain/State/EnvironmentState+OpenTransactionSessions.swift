import Foundation

/// Where the open-transaction guard asks and acts, per engine: PostgreSQL's pinned sessions (one per
/// database the tab used) or a MySQL tab's one connection.
extension EnvironmentState {
    /// The tab's open transactions; nil when its engine has no guard.
    func openTransactions(in tab: WorkspaceTab) async -> [QueryOpenTransaction]? {
        if let store = (tab.session as? PostgresSession)?.pinnedStore { return await store.openTransactions() }
        if let mysql = tab.session as? MySQLSession { return await mysql.openTransactions(startedAt: tab.query?.transactionState.since) }
        return nil
    }

    /// Commits (or rolls back) the tab's open transactions.
    func endTransactions(in tab: WorkspaceTab, commit: Bool) async throws {
        if let store = (tab.session as? PostgresSession)?.pinnedStore {
            try await store.endTransactions(commit: commit)
        } else if let mysql = tab.session as? MySQLSession {
            try await mysql.endTransactions(commit: commit)
        }
    }
}

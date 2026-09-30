import EchoSense
import Foundation
import PostgresKit

/// A query tab's PostgreSQL transaction (Echo Labs round 21, transaction state, accepted): the
/// footer's status pill follows it (TS3, TL2, TC1, TT2, TA2, F1), read from Echo's own tracking of
/// the pinned session (K1), and a notification reminds after 15 minutes idle inside one (R3).
extension EnvironmentState {
    func trackPostgresTransaction(for tab: WorkspaceTab, session: PostgresSession) {
        guard let query = tab.query else { return }
        // The tab's current database: switching databases keeps one store per tab.
        query.transactionStatusProvider = { [weak tab, weak session] () async -> QueryTransactionStatus? in
            guard let session, let store = session.pinnedStore else { return nil }
            let active = tab?.activeDatabaseName ?? ""
            switch await store.transactionStatus(for: active.isEmpty ? session.databaseName : active) {
            case .inTransaction?: return QueryTransactionStatus.open
            case .failed?: return QueryTransactionStatus.failed
            case .idle?: return QueryTransactionStatus.idle
            case nil: return nil
            }
        }
        // Round 21, timeouts: the server's own limit (SL1) and who holds a lock the tab waits for (LF3),
        // both read on other connections, never the running one.
        query.serverTimeLimitProvider = { [weak tab, weak session] () async -> TimeInterval? in
            guard let session, let store = session.pinnedStore else { return nil }
            let active = tab?.activeDatabaseName ?? ""
            return await store.serverStatementTimeout(for: active.isEmpty ? session.databaseName : active)
        }
        query.lockWaitProvider = { [weak session] () async -> QueryLockWait? in
            guard let session, let store = session.pinnedStore, let pid = await store.runningBackendPID(),
                  let holder = try? await session.client.blockingSessions(of: pid).first else { return nil }
            return QueryLockWait(
                holderPID: holder.pid, holderUser: holder.user, holderApplication: holder.applicationName,
                holderQuery: holder.query, holderState: holder.state, holderTransactionStartedAt: holder.transactionStartedAt
            )
        }
        let tabID = tab.id
        Task { @MainActor [weak self] in
            // One quiet check a minute; nothing runs on the server.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, let tab = self.tabStore.tabs.first(where: { $0.id == tabID }) else { return }
                self.remindAboutIdleTransaction(in: tab)
            }
        }
    }

    /// Shared by PostgreSQL and SQL Server tabs.
    func remindAboutIdleTransaction(in tab: WorkspaceTab) {
        guard let query = tab.query, query.transactionState != .none, !query.isExecuting, !query.transactionReminderSent,
              Date().timeIntervalSince(query.transactionLastActivity) >= QueryTransactionState.reminderIdleTime else { return }
        query.transactionReminderSent = true
        let server = tab.connection.connectionName.isEmpty ? tab.connection.host : tab.connection.connectionName
        let minutes = Int(Date().timeIntervalSince(query.transactionLastActivity) / 60)
        notificationEngine?.post(
            category: .generalInfo,
            icon: "arrow.triangle.branch",
            message: "Transaction still open: \(tab.title) has had a transaction open with nothing run for \(minutes) minutes. It holds its locks until you commit or roll back.",
            style: .warning,
            duration: 8,
            context: NotificationContext(serverName: server, connectionID: tab.connection.id, tabID: tab.id)
        )
    }
}

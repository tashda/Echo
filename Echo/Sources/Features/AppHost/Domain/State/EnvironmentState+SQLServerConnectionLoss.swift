import EchoSense
import Foundation

/// A query tab's SQL Server connection dropping (Echo Labs round 22, LC4: follows the PostgreSQL
/// decision CW2, RC2, WD2). Told the moment it drops; with a transaction open, Messages and a
/// notification with Reconnect, and runs wait for Reconnect; with nothing open the footer says
/// Disconnected and the next run reconnects. The footer's transaction pill follows the session.
extension EnvironmentState {
    /// Starts watching the tab's dedicated session, whatever its engine. Call once the tab has it.
    func watchConnectionLoss(for tab: WorkspaceTab, session: DatabaseSession) {
        if let sqlServer = session as? MSSQLDedicatedQuerySession {
            watchSQLServerConnectionLoss(for: tab, session: sqlServer)
        } else if let mysql = session as? MySQLSession {
            watchMySQLConnection(for: tab, session: mysql)
        } else {
            watchPostgresConnectionLoss(for: tab, session: session)
        }
    }

    private func watchSQLServerConnectionLoss(for tab: WorkspaceTab, session: MSSQLDedicatedQuerySession) {
        let tabID = tab.id
        session.setConnectionLostHandler { [weak self] database, transactionLost, isReminder in
            Task { @MainActor in
                self?.queryTabConnectionLost(tabID: tabID, database: database, transactionLost: transactionLost, isReminder: isReminder)
            }
        }
        guard let query = tab.query else { return }
        // The driver follows SQL Server's transaction notices, so this costs no round trip. With
        // XACT_ABORT ON a failed statement rolls the transaction back, so there is no Failed state.
        query.transactionStatusProvider = { [weak session] () async -> QueryTransactionStatus? in
            guard let session else { return nil }
            return session.isInTransaction ? .open : .idle
        }
        Task { @MainActor [weak self] in
            // One quiet check a minute; nothing runs on the server.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, let tab = self.tabStore.tabs.first(where: { $0.id == tabID }) else { return }
                self.remindAboutIdleTransaction(in: tab)
            }
        }
    }

    /// The Reconnect button on a SQL Server tab: a new session in the tab's database.
    func reconnectSQLServerTab(_ tabID: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabID }),
              let session = tab.session as? MSSQLDedicatedQuerySession else { return }
        let database = tab.query?.connectionLoss?.database ?? session.database ?? tab.connection.database
        tab.query?.isEstablishingConnection = true
        Task { @MainActor [weak self] in
            do {
                try await session.reconnect()
                tab.query?.connectionLoss = nil
                tab.query?.transactionState = .none
                tab.query?.appendMessage(message: QueryConnectionLossText.reconnected(database: database), severity: .info, category: "Connection")
            } catch {
                let reason = error.localizedDescription
                tab.query?.appendMessage(message: QueryConnectionLossText.reconnectFailed(database: database, reason: reason), severity: .error, category: "Connection")
                self?.notificationEngine?.post(
                    category: .connectionFailed,
                    message: QueryConnectionLossText.reconnectFailed(database: database, reason: reason),
                    duration: 5.0
                )
            }
            tab.query?.isEstablishingConnection = false
        }
    }
}

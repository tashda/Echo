import EchoSense
import Foundation

/// A query tab's MySQL or MariaDB connection and transaction, as for PostgreSQL and SQL Server
/// (Echo Labs rounds 21 and 22): a drop is told within seconds (with a transaction open, Messages
/// and a notification with Reconnect, and runs wait for Reconnect; with nothing open the footer
/// says Disconnected and the next run reconnects). The footer's pill follows the transaction, and
/// a notification reminds after 15 minutes idle inside one. The connection reports both with
/// every answer, so watching them costs no round trip. MySQL has no failed state: an error rolls
/// back only its statement.
extension EnvironmentState {
    /// How often the tab's socket is checked for a drop (no round trip).
    private static let mySQLConnectionCheckInterval: Duration = .seconds(2)

    func watchMySQLConnection(for tab: WorkspaceTab, session: MySQLSession) {
        let tabID = tab.id
        session.setConnectionLostHandler { [weak self] database, transactionLost, isReminder in
            Task { @MainActor in
                self?.queryTabConnectionLost(tabID: tabID, database: database, transactionLost: transactionLost, isReminder: isReminder)
            }
        }
        tab.query?.transactionStatusProvider = { [weak session] () async -> QueryTransactionStatus? in
            guard let session else { return nil }
            return await session.isInTransaction ? .open : .idle
        }
        Task { @MainActor [weak self, weak session] in
            var lastReminderCheck = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.mySQLConnectionCheckInterval)
                guard let self, let session, let tab = self.tabStore.tabs.first(where: { $0.id == tabID }) else { return }
                await session.checkConnection()
                // One quiet reminder check a minute.
                if ContinuousClock.now - lastReminderCheck >= .seconds(60) {
                    lastReminderCheck = .now
                    self.remindAboutIdleTransaction(in: tab)
                }
            }
        }
    }

    /// The Reconnect button on a MySQL tab: a new connection in the tab's database.
    func reconnectMySQLTab(_ tabID: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabID }),
              let session = tab.session as? MySQLSession else { return }
        let database = tab.query?.connectionLoss?.database ?? session.databaseName
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

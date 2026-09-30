import Foundation

/// A query tab's PostgreSQL connection dropping (Echo Labs round 21, connection lost, accepted):
/// told the moment it drops (CW2) in Messages and as a notification with Reconnect (CL1 plus a
/// notification, RC2), in the tab's words (WD2), and recorded in the history (H1). With nothing
/// open the footer just says Disconnected and the next run reconnects (I1). Run again is never
/// offered (RR3).
extension EnvironmentState {
    /// Starts watching the tab's pinned PostgreSQL connections. Call once the tab has its session.
    func watchPostgresConnectionLoss(for tab: WorkspaceTab, session: DatabaseSession) {
        guard let postgres = session as? PostgresSession, let store = postgres.pinnedStore else { return }
        let tabID = tab.id
        Task {
            await store.setConnectionLostHandler { [weak self] database, transactionLost, isReminder in
                Task { @MainActor in
                    self?.postgresConnectionLost(tabID: tabID, database: database, transactionLost: transactionLost, isReminder: isReminder)
                }
            }
        }
    }

    private func postgresConnectionLost(tabID: UUID, database: String, transactionLost: Bool, isReminder: Bool) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabID }), let query = tab.query else { return }
        let context = NotificationContext(
            serverName: tab.connection.connectionName.isEmpty ? tab.connection.host : tab.connection.connectionName,
            connectionID: tab.connection.id,
            tabID: tabID,
            action: transactionLost ? .reconnectTab : nil
        )
        guard transactionLost else {
            query.connectionLoss = .idle(database: database)
            notificationEngine?.post(
                category: .connectionDisconnected, icon: NotificationCategory.connectionDisconnected.defaultIcon,
                message: PostgresConnectionLossText.droppedIdle(tabTitle: tab.title, database: database),
                style: .info, context: context, showsToast: false
            )
            return
        }
        query.connectionLoss = .transactionLost(database: database)
        if !isReminder {
            query.appendMessage(message: PostgresConnectionLossText.droppedWithTransaction(database: database), severity: .error, category: "Connection")
        }
        // A run while waiting for Reconnect brings the notification (and its button) back.
        notificationEngine?.post(
            category: .connectionDisconnected, icon: "bolt.horizontal.circle.fill",
            message: PostgresConnectionLossText.notification(tabTitle: tab.title, database: database),
            style: .error, duration: 8, context: context
        )
    }

    /// Whether a notification's button still applies.
    func canPerform(_ action: NotificationAction, context: NotificationContext?) -> Bool {
        switch action {
        case .reconnectTab:
            guard let tabID = context?.tabID, let tab = tabStore.tabs.first(where: { $0.id == tabID }) else { return false }
            if case .transactionLost = tab.query?.connectionLoss { return true }
            return false
        }
    }

    func perform(_ action: NotificationAction, context: NotificationContext?) {
        switch action {
        case .reconnectTab:
            guard let tabID = context?.tabID else { return }
            reconnectPostgresTab(tabID)
        }
    }

    /// The Reconnect button: a new session for the tab's database.
    func reconnectPostgresTab(_ tabID: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabID }),
              let postgres = tab.session as? PostgresSession, let store = postgres.pinnedStore else { return }
        let database = postgres.databaseName
        tab.query?.isEstablishingConnection = true
        Task { @MainActor [weak self] in
            do {
                try await store.reconnect(database: database)
                tab.query?.connectionLoss = nil
                tab.query?.appendMessage(message: PostgresConnectionLossText.reconnected(database: database), severity: .info, category: "Connection")
            } catch {
                let reason = error.localizedDescription
                tab.query?.appendMessage(message: PostgresConnectionLossText.reconnectFailed(database: database, reason: reason), severity: .error, category: "Connection")
                self?.notificationEngine?.post(
                    category: .connectionFailed,
                    message: PostgresConnectionLossText.reconnectFailed(database: database, reason: reason),
                    duration: 5.0
                )
            }
            tab.query?.isEstablishingConnection = false
        }
    }
}

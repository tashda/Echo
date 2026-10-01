import Foundation

/// Following a toast or history row back to where it happened (plan N3).
extension EnvironmentState {
    /// Whether the event's tab is still open or its server still connected.
    func canReveal(_ context: NotificationContext?) -> Bool {
        guard let context else { return false }
        if let tabID = context.tabID, tabStore.tabs.contains(where: { $0.id == tabID }) { return true }
        if let connectionID = context.connectionID {
            return sessionGroup.activeSessions.contains { $0.connection.id == connectionID }
        }
        return false
    }

    /// Brings the event's tab to the front, or else selects its server.
    func reveal(_ context: NotificationContext?) {
        guard let context else { return }
        if let tabID = context.tabID, let tab = tabStore.tabs.first(where: { $0.id == tabID }) {
            sessionGroup.setActiveSession(tab.connectionSessionID)
            tabStore.activeTabId = tab.id
        } else if let connectionID = context.connectionID,
                  let session = sessionGroup.activeSessions.first(where: { $0.connection.id == connectionID }) {
            sessionGroup.setActiveSession(session.id)
        }
    }
}

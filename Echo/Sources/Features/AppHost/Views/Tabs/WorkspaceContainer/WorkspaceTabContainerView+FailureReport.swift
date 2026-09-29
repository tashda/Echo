import Foundation

extension WorkspaceTabContainerView {
    /// Records a failed query in the notification history, with a toast only when its tab isn't in
    /// front: the results card already shows the error there (plan N4).
    func reportQueryFailure(_ message: String, tab: WorkspaceTab) {
        let serverName = tab.connection.connectionName.isEmpty ? tab.connection.host : tab.connection.connectionName
        environmentState.notificationEngine?.post(
            category: .queryFailed,
            icon: NotificationCategory.queryFailed.defaultIcon,
            message: "\(tab.title) failed: \(message)",
            style: .error,
            context: NotificationContext(serverName: serverName, connectionID: tab.connection.id, tabID: tab.id),
            showsToast: tabStore.activeTabId != tab.id
        )
    }
}

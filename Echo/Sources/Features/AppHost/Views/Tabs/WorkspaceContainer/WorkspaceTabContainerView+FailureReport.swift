import Foundation
#if os(macOS)
import AppKit
#endif

extension WorkspaceTabContainerView {
    /// Records a failed query in the notification history, with a toast only when its tab isn't in
    /// front: the results card already shows the error there (plan N4).
    func reportQueryFailure(_ message: String, tab: WorkspaceTab) {
        let serverName = tab.connection.connectionName.isEmpty ? tab.connection.host : tab.connection.connectionName
        environmentState.notificationEngine?.post(
            category: .queryFailed,
            icon: NotificationCategory.queryFailed.defaultIcon,
            // Round 21, timeouts (TF4): a stop by the time limit says whose limit it was.
            message: tab.query?.timeLimitStop.map { "\(tab.title) \($0.explanation.prefix(1).lowercased() + $0.explanation.dropFirst())" }
                ?? "\(tab.title) failed: \(message)",
            style: .error,
            context: NotificationContext(
                serverName: serverName, connectionID: tab.connection.id, tabID: tab.id,
                action: tab.query?.errorMark != nil ? .goToError : nil
            ),
            showsToast: tabStore.activeTabId != tab.id || !Self.echoIsFrontmost
        )
    }

    /// A notification also helps when another app is in front (round 21, TF4: "when you're elsewhere").
    static var echoIsFrontmost: Bool {
        #if os(macOS)
        return NSApp?.isActive ?? true
        #else
        return true
        #endif
    }
}

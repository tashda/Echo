import SwiftUI

/// The toolbar bell (plan N3): shows the notification history in the inspector's column (round 15,
/// option B), with a badge for unread events.
struct NotificationBellToolbarButton: View {
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState

    private var unreadCount: Int { environmentState.notificationEngine?.history.unreadCount ?? 0 }

    var body: some View {
        Button {
            appState.toggleNotificationHistory()
        } label: {
            Label("Notifications", systemImage: appState.isNotificationHistoryVisible ? "bell.fill" : "bell")
        }
        .labelStyle(.iconOnly)
        .badge(unreadCount)
        .onChange(of: appState.isNotificationHistoryVisible) { _, isVisible in
            if isVisible { environmentState.notificationEngine?.history.markAllRead() }
        }
        .help(unreadCount > 0 ? "Notifications (\(unreadCount) unread)" : "Notifications")
        .accessibilityLabel(unreadCount > 0 ? "Notifications, \(unreadCount) unread" : "Notifications")
    }
}

import SwiftUI

/// The toolbar bell (plan N3): opens the notification history, with a badge for unread events.
struct NotificationBellToolbarButton: View {
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState

    private var unreadCount: Int { environmentState.notificationEngine?.history.unreadCount ?? 0 }

    var body: some View {
        Button {
            appState.isNotificationHistoryVisible.toggle()
        } label: {
            Label("Notifications", systemImage: appState.isNotificationHistoryVisible ? "bell.fill" : "bell")
        }
        .labelStyle(.iconOnly)
        .badge(unreadCount)
        .help(unreadCount > 0 ? "Notifications (\(unreadCount) unread)" : "Notifications")
        .accessibilityLabel(unreadCount > 0 ? "Notifications, \(unreadCount) unread" : "Notifications")
    }
}

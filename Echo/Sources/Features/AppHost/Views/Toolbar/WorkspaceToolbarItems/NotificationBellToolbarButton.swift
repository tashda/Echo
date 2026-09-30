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
        // A system popover, so the history grows out of the bell wherever the bell is, in the
        // popover's own glass (like the database switcher).
        .popover(isPresented: Bindable(appState).isNotificationHistoryVisible, arrowEdge: .bottom) {
            if let history = environmentState.notificationEngine?.history {
                NotificationHistoryCard(history: history) { appState.isNotificationHistoryVisible = false }
            }
        }
        .onChange(of: appState.isNotificationHistoryVisible) { _, isVisible in
            if isVisible { environmentState.notificationEngine?.history.markAllRead() }
        }
        .help(unreadCount > 0 ? "Notifications (\(unreadCount) unread)" : "Notifications")
        .accessibilityLabel(unreadCount > 0 ? "Notifications, \(unreadCount) unread" : "Notifications")
    }
}

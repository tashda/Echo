import SwiftUI

/// The toolbar bell (plan N3): shows the notification history in the inspector's column (round 15,
/// option B), with a badge for unread events. While a long operation runs (a backup, a restore,
/// DDL), a small spinner sits on the bell (round 34, AS2); query runs show on Run instead.
struct NotificationBellToolbarButton: View {
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ActivityEngine.self) private var activityEngine

    /// True once an operation has run for `LayoutTokens.Bell.busyDelay`, so quick work doesn't flicker.
    @State private var isBusy = false

    private var unreadCount: Int { environmentState.notificationEngine?.history.unreadCount ?? 0 }
    private var running: [TrackedOperation] { activityEngine.bellOperations }

    var body: some View {
        Button {
            appState.toggleNotificationHistory()
        } label: {
            Label {
                Text("Notifications")
            } icon: {
                Image(systemName: appState.isNotificationHistoryVisible ? "bell.fill" : "bell")
                    .overlay(alignment: .bottomTrailing) {
                        if isBusy {
                            ProgressView()
                                .controlSize(.mini)
                                .offset(x: SpacingTokens.xxs2, y: SpacingTokens.xxs)
                                .transition(.opacity)
                        }
                    }
            }
        }
        .labelStyle(.iconOnly)
        .badge(unreadCount)
        .task(id: running.first?.id) {
            guard let first = running.first else {
                withAnimation(.easeOut(duration: 0.2)) { isBusy = false }
                return
            }
            let waited = Date().timeIntervalSince(first.startedAt)
            let remaining = LayoutTokens.Bell.busyDelay - waited
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { isBusy = true }
        }
        .onChange(of: appState.isNotificationHistoryVisible) { _, isVisible in
            if isVisible { environmentState.notificationEngine?.history.markAllRead() }
        }
        .help(helpText)
        .accessibilityLabel(accessibilityText)
    }

    private var runningText: String? {
        guard isBusy, let first = running.first else { return nil }
        return running.count == 1 ? "\(first.label) running" : "\(running.count) operations running"
    }

    private var helpText: String {
        let base = unreadCount > 0 ? "Notifications (\(unreadCount) unread)" : "Notifications"
        return runningText.map { "\(base) · \($0)" } ?? base
    }

    private var accessibilityText: String {
        let base = unreadCount > 0 ? "Notifications, \(unreadCount) unread" : "Notifications"
        return runningText.map { "\(base), \($0)" } ?? base
    }
}

extension LayoutTokens {
    /// The toolbar bell (round 34).
    enum Bell {
        /// How long an operation runs before the bell shows it.
        static let busyDelay: TimeInterval = 1
    }
}

import SwiftUI
import UserNotifications

/// Central notification router: records every event in the history behind the toolbar bell, then
/// shows an in-app toast and/or a native notification as the user's preferences allow (plan N3).
@MainActor @Observable
final class NotificationEngine: NSObject, UNUserNotificationCenterDelegate {
    @ObservationIgnored private let toastPresenter: StatusToastPresenter
    @ObservationIgnored private let preferencesProvider: () -> NotificationPreferences
    /// Where events come from when the caller doesn't say: the active server and tab.
    @ObservationIgnored private let contextProvider: () -> NotificationContext?
    @ObservationIgnored private var hasRequestedAuthorization = false

    let history: NotificationHistory

    init(
        toastPresenter: StatusToastPresenter,
        history: NotificationHistory = NotificationHistory(),
        preferencesProvider: @escaping () -> NotificationPreferences,
        contextProvider: @escaping () -> NotificationContext? = { nil }
    ) {
        self.toastPresenter = toastPresenter
        self.history = history
        self.preferencesProvider = preferencesProvider
        self.contextProvider = contextProvider
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Post a typed notification event. Messages are centralized in ``NotificationEvent``.
    /// Callable from any isolation; delivery hops to the main actor.
    nonisolated func post(_ event: NotificationEvent) {
        let category = event.category
        let icon = event.icon ?? category.defaultIcon
        let style = event.style ?? category.defaultStyle
        let duration = event.duration ?? 3.0
        post(category: category, icon: icon, message: event.message, style: style, duration: duration)
    }

    /// Post a notification using the category's default icon and style.
    /// - Note: Prefer ``post(_:)`` with a ``NotificationEvent`` for new code.
    nonisolated func post(category: NotificationCategory, message: String, duration: TimeInterval = 3.0) {
        post(category: category, icon: category.defaultIcon, message: message, style: category.defaultStyle, duration: duration)
    }

    /// Post a notification with explicit icon and style overrides.
    nonisolated func post(
        category: NotificationCategory,
        icon: String,
        message: String,
        style: StatusToastView.StatusToastStyle = .info,
        duration: TimeInterval = 3.0,
        context: NotificationContext? = nil,
        showsToast: Bool = true
    ) {
        Task { @MainActor in
            self.deliver(
                category: category, icon: icon, message: message, style: style,
                duration: duration, context: context, showsToast: showsToast
            )
        }
    }

    private func deliver(
        category: NotificationCategory,
        icon: String,
        message: String,
        style: StatusToastView.StatusToastStyle,
        duration: TimeInterval,
        context: NotificationContext?,
        showsToast: Bool
    ) {
        let context = context ?? contextProvider()
        // Every event is recorded, even when its toast is muted.
        history.append(NotificationRecord(category: category, message: message, severity: style.severity, context: context))

        let preferences = preferencesProvider()
        guard showsToast, preferences.isEnabled(category) else { return }

        switch preferences.delivery {
        case .inApp:
            toastPresenter.show(icon: icon, message: message, style: style, duration: duration, context: context)
        case .native:
            sendNativeNotification(category: category, message: message)
        case .both:
            toastPresenter.show(icon: icon, message: message, style: style, duration: duration, context: context)
            sendNativeNotification(category: category, message: message)
        }
    }

    // MARK: - Native macOS

    private func sendNativeNotification(category: NotificationCategory, message: String) {
        sendNativeNotification(title: category.group.displayName, body: message)
    }

    /// A macOS Notification Center banner, whatever the delivery preference says.
    func sendNativeNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()

        if !hasRequestedAuthorization {
            hasRequestedAuthorization = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banner notifications even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

extension StatusToastView.StatusToastStyle {
    var severity: NotificationRecord.Severity {
        switch self {
        case .success: .success
        case .info: .info
        case .warning: .warning
        case .error: .error
        }
    }
}

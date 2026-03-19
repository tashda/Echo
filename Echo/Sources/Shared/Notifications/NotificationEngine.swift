import SwiftUI
import UserNotifications

/// Central notification router that dispatches to in-app toasts
/// and/or native macOS notifications based on user preferences.
@Observable
final class NotificationEngine: NSObject, UNUserNotificationCenterDelegate {
    @ObservationIgnored private let toastPresenter: StatusToastPresenter
    @ObservationIgnored private let preferencesProvider: () -> NotificationPreferences
    @ObservationIgnored private var hasRequestedAuthorization = false
    @ObservationIgnored private var lastMessageTimestamp: Date?

    /// All notifications posted through the engine, displayed in the Notifications panel segment.
    var notificationMessages: [QueryExecutionMessage] = []

    init(
        toastPresenter: StatusToastPresenter,
        preferencesProvider: @escaping () -> NotificationPreferences
    ) {
        self.toastPresenter = toastPresenter
        self.preferencesProvider = preferencesProvider
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Post a typed notification event. Messages are centralized in ``NotificationEvent``.
    func post(_ event: NotificationEvent) {
        let category = event.category
        let icon = event.icon ?? category.defaultIcon
        let style = event.style ?? category.defaultStyle
        let duration = event.duration ?? 3.0
        post(category: category, icon: icon, message: event.message, style: style, duration: duration)
    }

    /// Post a notification using the category's default icon and style.
    /// - Note: Prefer ``post(_:)`` with a ``NotificationEvent`` for new code.
    func post(category: NotificationCategory, message: String, duration: TimeInterval = 3.0) {
        post(category: category, icon: category.defaultIcon, message: message, style: category.defaultStyle, duration: duration)
    }

    /// Post a notification with explicit icon and style overrides.
    func post(
        category: NotificationCategory,
        icon: String,
        message: String,
        style: StatusToastView.StatusToastStyle = .info,
        duration: TimeInterval = 3.0
    ) {
        let preferences = preferencesProvider()
        guard preferences.isEnabled(category) else { return }

        // Store in notification messages for the panel
        appendNotificationMessage(message, category: category.group.displayName, style: style)

        switch preferences.delivery {
        case .inApp:
            showToast(icon: icon, message: message, style: style, duration: duration)
        case .native:
            sendNativeNotification(category: category, message: message)
        case .both:
            showToast(icon: icon, message: message, style: style, duration: duration)
            sendNativeNotification(category: category, message: message)
        }
    }

    func clearNotifications() {
        notificationMessages.removeAll()
        lastMessageTimestamp = nil
    }

    // MARK: - Notification Message Storage

    private func appendNotificationMessage(_ text: String, category: String, style: StatusToastView.StatusToastStyle) {
        let now = Date()
        let delta = lastMessageTimestamp.map { now.timeIntervalSince($0) } ?? 0
        let severity: QueryExecutionMessage.Severity = switch style {
        case .success: .success
        case .error: .error
        case .warning: .warning
        case .info: .info
        }
        let message = QueryExecutionMessage(
            index: notificationMessages.count + 1,
            category: category,
            message: text,
            timestamp: now,
            severity: severity,
            delta: delta
        )
        notificationMessages.append(message)
        lastMessageTimestamp = now
    }

    // MARK: - In-App

    private func showToast(icon: String, message: String, style: StatusToastView.StatusToastStyle, duration: TimeInterval) {
        toastPresenter.show(icon: icon, message: message, style: style, duration: duration)
    }

    // MARK: - Native macOS

    private func sendNativeNotification(category: NotificationCategory, message: String) {
        let center = UNUserNotificationCenter.current()

        if !hasRequestedAuthorization {
            hasRequestedAuthorization = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        let content = UNMutableNotificationContent()
        content.title = category.group.displayName
        content.body = message
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

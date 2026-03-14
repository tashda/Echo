import SwiftUI
import UserNotifications
import Combine

/// Central notification router that dispatches to in-app toasts
/// and/or native macOS notifications based on user preferences.
@MainActor
final class NotificationEngine: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private let toastCoordinator: StatusToastCoordinator
    private let preferencesProvider: () -> NotificationPreferences
    private var hasRequestedAuthorization = false

    init(
        toastCoordinator: StatusToastCoordinator,
        preferencesProvider: @escaping () -> NotificationPreferences
    ) {
        self.toastCoordinator = toastCoordinator
        self.preferencesProvider = preferencesProvider
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Post a notification using the category's default icon and style.
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

    // MARK: - In-App

    private func showToast(icon: String, message: String, style: StatusToastView.StatusToastStyle, duration: TimeInterval) {
        toastCoordinator.show(icon: icon, message: message, style: style, duration: duration)
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

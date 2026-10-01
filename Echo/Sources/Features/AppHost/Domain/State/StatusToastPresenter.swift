import SwiftUI

/// The in-window toasts (plan N2): up to three at once, newest on top. A repeat of a showing toast
/// counts up ("×3") instead of stacking; hovering one keeps it; errors stay until dismissed.
@MainActor @Observable
final class StatusToastPresenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let icon: String
        let message: String
        let style: StatusToastView.StatusToastStyle
        var count = 1
        var context: NotificationContext?

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id && lhs.count == rhs.count }

        /// Errors stay until dismissed.
        var staysUntilDismissed: Bool { style == .error }
    }

    static let maximumVisible = 3

    private(set) var toasts: [Toast] = []
    /// The toast under the pointer; it neither times out nor moves.
    var hoveredID: UUID?

    @ObservationIgnored private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    func show(
        icon: String,
        message: String,
        style: StatusToastView.StatusToastStyle = .info,
        duration: TimeInterval = 3.0,
        context: NotificationContext? = nil
    ) {
        let toast: Toast
        if let index = toasts.firstIndex(where: { $0.message == message && $0.style == style }) {
            var repeated = toasts.remove(at: index)
            repeated.count += 1
            toast = repeated
        } else {
            toast = Toast(icon: icon, message: message, style: style, context: context)
        }
        toasts.insert(toast, at: 0)
        while toasts.count > Self.maximumVisible, let dropped = toasts.popLast() {
            dismissTasks.removeValue(forKey: dropped.id)?.cancel()
        }
        AccessibilityNotification.Announcement(message).post()
        scheduleDismiss(toast, after: duration)
    }

    func dismiss(_ id: UUID) {
        dismissTasks.removeValue(forKey: id)?.cancel()
        toasts.removeAll { $0.id == id }
        if hoveredID == id { hoveredID = nil }
    }

    /// Dismisses the newest toast.
    func dismiss() {
        if let newest = toasts.first { dismiss(newest.id) }
    }

    private func scheduleDismiss(_ toast: Toast, after duration: TimeInterval) {
        dismissTasks.removeValue(forKey: toast.id)?.cancel()
        guard !toast.staysUntilDismissed else { return }
        dismissTasks[toast.id] = Task(name: "toast-dismiss") { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            // A hovered toast waits until the pointer leaves.
            while !Task.isCancelled, self?.hoveredID == toast.id {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            self?.dismiss(toast.id)
        }
    }
}

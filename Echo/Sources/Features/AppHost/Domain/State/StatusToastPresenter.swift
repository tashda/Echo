import SwiftUI

/// Manages transient status toast notifications.
///
/// Connection events, index updates, and other brief status changes
/// are shown as floating toasts that auto-dismiss after a delay.
@Observable
final class StatusToastPresenter: @unchecked Sendable {
    struct Toast: Identifiable, Equatable, Sendable {
        let id = UUID()
        let icon: String
        let message: String
        let style: StatusToastView.StatusToastStyle

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    var currentToast: Toast?

    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    func show(icon: String, message: String, style: StatusToastView.StatusToastStyle = .info, duration: TimeInterval = 3.0) {
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            currentToast = Toast(icon: icon, message: message, style: style)
        }
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentToast = nil
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = nil
        }
    }
}

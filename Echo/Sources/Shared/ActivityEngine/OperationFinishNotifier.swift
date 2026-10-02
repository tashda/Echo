import Foundation

/// Round 34 (AS2): long operations report through the bell. While one runs the bell spins; when it
/// ends, its own notification says so. An operation that posted none gets one from here, so no
/// long operation ends silently: "Backup shop finished in 1:12" or "Backup shop failed: reason".
@MainActor
final class OperationFinishNotifier {
    /// Operations shorter than this end quietly when they succeed; the spinner was enough.
    /// A failure is always told, however quickly it came: nothing else on screen says so.
    nonisolated static let minimumDuration: TimeInterval = 5
    /// How long to wait for the operation's own notification, which callers post around `succeed()`.
    static let grace: Duration = .seconds(1)
    /// A notification recorded this close to the end counts as the operation's own.
    nonisolated static let matchWindow: TimeInterval = 2

    private let notificationEngine: NotificationEngine
    private let contextProvider: (UUID?) -> NotificationContext?

    init(notificationEngine: NotificationEngine, contextProvider: @escaping (UUID?) -> NotificationContext?) {
        self.notificationEngine = notificationEngine
        self.contextProvider = contextProvider
    }

    func operationFinished(_ result: OperationResult) {
        guard Self.isLongEnough(result) else { return }
        Task(name: "Finish notice for \(result.label)") { [weak self] in
            try? await Task.sleep(for: Self.grace)
            guard let self else { return }
            guard !Self.alreadyNotified(result, records: self.notificationEngine.history.records) else { return }
            let isSuccess = result.isSuccess
            self.notificationEngine.post(
                category: isSuccess ? .generalSuccess : .generalError,
                icon: (isSuccess ? NotificationCategory.generalSuccess : .generalError).defaultIcon,
                message: Self.message(for: result),
                style: isSuccess ? .success : .error,
                duration: isSuccess ? 3 : 5,
                context: self.contextProvider(result.connectionSessionID)
            )
        }
    }

    /// Shown on the bell and not cancelled; a success also needs at least `minimumDuration`.
    nonisolated static func isLongEnough(_ result: OperationResult) -> Bool {
        guard result.showsOnBell else { return false }
        switch result.outcome {
        case .cancelled: return false
        case .failed: return true
        default: return result.duration >= minimumDuration
        }
    }

    /// Whether a notification was recorded around the operation's end: its own. A failure
    /// counts only an error, so an unrelated toast close by never hides it.
    nonisolated static func alreadyNotified(_ result: OperationResult, records: [NotificationRecord]) -> Bool {
        records.contains {
            abs($0.date.timeIntervalSince(result.completedAt)) <= matchWindow
                && (!result.isFailure || $0.severity == .error)
        }
    }

    nonisolated static func message(for result: OperationResult) -> String {
        switch result.outcome {
        case .failed(let reason) where !reason.isEmpty:
            "\(result.label) failed: \(reason)"
        case .failed:
            "\(result.label) failed after \(ElapsedTimeText.format(result.duration))"
        default:
            "\(result.label) finished in \(ElapsedTimeText.format(result.duration))"
        }
    }
}

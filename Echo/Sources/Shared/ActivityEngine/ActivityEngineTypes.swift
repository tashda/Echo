import Foundation

// MARK: - Tracked Operation

/// A currently-running operation tracked by the activity engine.
struct TrackedOperation: Identifiable {
    let id: UUID
    let label: String
    let connectionSessionID: UUID?
    let startedAt: Date
    var progress: Double?
    var message: String?
}

// MARK: - Operation Result

/// The outcome of a completed operation, displayed briefly in the toolbar.
struct OperationResult: Identifiable {
    let id: UUID
    let label: String
    let connectionSessionID: UUID?
    let outcome: Outcome
    let completedAt: Date
    let duration: TimeInterval

    enum Outcome {
        case succeeded
        case failed(message: String)
        case cancelled
    }

    var isSuccess: Bool {
        if case .succeeded = outcome { return true }
        return false
    }

    var isFailure: Bool {
        if case .failed = outcome { return true }
        return false
    }
}

// MARK: - Operation Handle

/// A handle returned by `ActivityEngine.begin()` that the caller uses to report
/// progress and completion. Non-Sendable — stays on MainActor by design.
final class OperationHandle {
    let id: UUID
    private weak var engine: ActivityEngine?
    private var isFinished = false

    init(id: UUID, engine: ActivityEngine) {
        self.id = id
        self.engine = engine
    }

    func updateProgress(_ fraction: Double, message: String? = nil) {
        guard !isFinished else { return }
        engine?.updateOperation(id, progress: fraction, message: message)
    }

    func updateMessage(_ message: String) {
        guard !isFinished else { return }
        engine?.updateOperation(id, progress: nil, message: message)
    }

    func succeed() {
        guard !isFinished else { return }
        isFinished = true
        engine?.finishOperation(id, outcome: .succeeded)
    }

    func fail(_ message: String = "") {
        guard !isFinished else { return }
        isFinished = true
        engine?.finishOperation(id, outcome: .failed(message: message))
    }

    func cancel() {
        guard !isFinished else { return }
        isFinished = true
        engine?.finishOperation(id, outcome: .cancelled)
    }
}

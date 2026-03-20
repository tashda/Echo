import Foundation
import Observation

/// Central hub that tracks all long-running operations across the app.
///
/// Any component can call `begin()` to register an operation. The returned
/// `OperationHandle` is used to report progress and completion. The toolbar
/// observes this engine to show aggregate activity state.
@Observable
final class ActivityEngine: @unchecked Sendable {

    // MARK: - Published State

    /// All currently-running operations, keyed by ID.
    private(set) var operations: [UUID: TrackedOperation] = [:]

    /// The most recently completed/failed operation (auto-clears after a delay).
    private(set) var lastResult: OperationResult?

    // MARK: - Private

    private var resultClearTask: Task<Void, Never>?

    // MARK: - Begin

    /// Start tracking a new operation. Returns a handle the caller uses to
    /// report progress and signal completion.
    ///
    /// - Parameters:
    ///   - label: Human-readable description shown in the toolbar tooltip (e.g. "Backup mydb").
    ///   - connectionSessionID: The connection this operation belongs to. Pass `nil` for global operations.
    /// - Returns: An `OperationHandle` — call `succeed()`, `fail()`, or `cancel()` when done.
    @discardableResult
    func begin(_ label: String, connectionSessionID: UUID? = nil) -> OperationHandle {
        let id = UUID()
        let operation = TrackedOperation(
            id: id,
            label: label,
            connectionSessionID: connectionSessionID,
            startedAt: Date(),
            progress: nil,
            message: nil
        )
        operations[id] = operation

        // Clear any lingering result when new work starts
        if let lastResult, lastResult.connectionSessionID == connectionSessionID {
            resultClearTask?.cancel()
            resultClearTask = nil
            self.lastResult = nil
        }

        return OperationHandle(id: id, engine: self)
    }

    // MARK: - Update (called by OperationHandle)

    func updateOperation(_ id: UUID, progress: Double?, message: String?) {
        guard operations[id] != nil else { return }
        if let progress {
            operations[id]?.progress = progress
        }
        if let message {
            operations[id]?.message = message
        }
    }

    func finishOperation(_ id: UUID, outcome: OperationResult.Outcome) {
        guard let operation = operations.removeValue(forKey: id) else { return }

        let result = OperationResult(
            id: operation.id,
            label: operation.label,
            connectionSessionID: operation.connectionSessionID,
            outcome: outcome,
            completedAt: Date(),
            duration: Date().timeIntervalSince(operation.startedAt)
        )

        // Only show result for non-cancelled operations
        if case .cancelled = outcome { return }

        lastResult = result
        scheduleResultClear(isFailure: result.isFailure)
    }

    // MARK: - Queries

    /// Whether any operation is currently running.
    var isActive: Bool { !operations.isEmpty }

    /// Number of concurrently running operations.
    var activeCount: Int { operations.count }

    /// Whether any operation is running for a specific connection.
    func isActive(for connectionSessionID: UUID) -> Bool {
        operations.values.contains { $0.connectionSessionID == connectionSessionID }
    }

    /// All operations for a specific connection.
    func operations(for connectionSessionID: UUID) -> [TrackedOperation] {
        operations.values.filter { $0.connectionSessionID == connectionSessionID }
    }

    /// The active operation label for a connection (first running operation).
    func activeLabel(for connectionSessionID: UUID) -> String? {
        operations.values.first { $0.connectionSessionID == connectionSessionID }?.label
    }

    /// The active message for a connection (first running operation with a message).
    func activeMessage(for connectionSessionID: UUID) -> String? {
        operations.values.first {
            $0.connectionSessionID == connectionSessionID && $0.message != nil
        }?.message
    }

    // MARK: - Private

    private func scheduleResultClear(isFailure: Bool) {
        resultClearTask?.cancel()
        let nanoseconds: UInt64 = isFailure ? 3_000_000_000 : 1_500_000_000
        resultClearTask = Task {
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            resultClearTask = nil
            lastResult = nil
        }
    }
}

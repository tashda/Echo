import Foundation
import Observation

/// Central hub that tracks all long-running operations across the app.
///
/// Any component can call `begin()` to register an operation. The returned
/// `OperationHandle` is used to report progress and completion. The toolbar's bell
/// observes this engine and spins while a long operation runs (round 34, AS2).
@Observable
final class ActivityEngine: @unchecked Sendable {

    // MARK: - Published State

    /// All currently-running operations, keyed by ID.
    private(set) var operations: [UUID: TrackedOperation] = [:]

    // MARK: - Begin

    /// Start tracking a new operation. Returns a handle the caller uses to
    /// report progress and signal completion.
    ///
    /// - Parameters:
    ///   - label: Human-readable description shown in the toolbar tooltip (e.g. "Backup mydb").
    ///   - connectionSessionID: The connection this operation belongs to. Pass `nil` for global operations.
    ///   - showsOnBell: False for work that shows its own progress where it was started (a query run on Run).
    /// - Returns: An `OperationHandle` — call `succeed()`, `fail()`, or `cancel()` when done.
    @discardableResult
    func begin(_ label: String, connectionSessionID: UUID? = nil, showsOnBell: Bool = true) -> OperationHandle {
        let id = UUID()
        let operation = TrackedOperation(
            id: id,
            label: label,
            connectionSessionID: connectionSessionID,
            startedAt: Date(),
            showsOnBell: showsOnBell,
            progress: nil,
            message: nil
        )
        operations[id] = operation
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
        operations.removeValue(forKey: id)
    }

    // MARK: - Queries

    /// Whether any operation is currently running.
    var isActive: Bool { !operations.isEmpty }

    /// Number of concurrently running operations.
    var activeCount: Int { operations.count }

    /// What the bell shows while it runs, oldest first.
    var bellOperations: [TrackedOperation] {
        operations.values.filter(\.showsOnBell).sorted { $0.startedAt < $1.startedAt }
    }

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
}

import Foundation

/// Result of a single batch within a multi-batch execution.
public struct BatchResult: Sendable {
    /// Zero-based index of this batch in the execution sequence.
    public let batchIndex: Int
    /// All result sets produced by this batch (a batch can have multiple SELECTs).
    public let resultSets: [QueryResultSet]
    /// Error message if this batch failed. Nil if it succeeded.
    public let error: String?
    /// Server messages for this batch (info, warnings, row counts).
    public let messages: [ServerMessage]
    /// Not run because an earlier statement failed (PostgreSQL scripts stop on error, round 21 E3).
    public var skipped = false
    /// How long the batch took, when the engine measures it.
    public var duration: TimeInterval?

    public var succeeded: Bool { error == nil && !skipped }
}

/// Progress updates emitted during multi-batch execution.
public struct BatchProgressUpdate: Sendable {
    public let batchIndex: Int
    public let batchCount: Int
    public let event: BatchProgressEvent
}

/// Events within a single batch's execution.
public enum BatchProgressEvent: Sendable {
    case started
    case streamUpdate(QueryStreamUpdate)
    case completed
    case failed(String)
}

/// Callback for receiving progress during multi-batch execution.
public typealias BatchProgressHandler = @Sendable (BatchProgressUpdate) -> Void

/// Maps a result set tab to its source batch in a multi-batch execution.
public struct BatchResultLabel: Sendable {
    public let batchIndex: Int
    public let resultSetIndexInBatch: Int
}

import Foundation

/// A transaction still open on one of a query tab's sessions (Echo Labs round 21, open transaction
/// on close): what the alert says about it.
struct QueryOpenTransaction: Sendable, Equatable {
    let database: String
    /// A statement in it failed; only ROLLBACK helps (PostgreSQL).
    let failed: Bool
    let startedAt: Date?
    /// Statements run in it, when the engine counts them (0: not said).
    let statements: Int
}

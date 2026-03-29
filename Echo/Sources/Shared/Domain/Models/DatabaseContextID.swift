import Foundation

/// Identifies a specific database within a specific connection session.
/// Used to pass explicit database context to tabs, tools, and views
/// instead of relying on shared mutable state.
struct DatabaseContextID: Hashable, Sendable, Codable {
    let connectionSessionID: UUID
    let databaseName: String
}

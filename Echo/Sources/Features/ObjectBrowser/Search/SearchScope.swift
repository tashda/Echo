import Foundation

/// Defines the scope of a search in the Search Sidebar.
enum SearchScope: Hashable {
    /// Search across all connected servers.
    case allServers
    /// Search within a specific server connection.
    case server(connectionSessionID: UUID)
    /// Search within a specific database on a specific server.
    case database(connectionSessionID: UUID, databaseName: String)

    /// Returns true if the given session is within this scope.
    func includes(sessionID: UUID) -> Bool {
        switch self {
        case .allServers:
            return true
        case .server(let id):
            return id == sessionID
        case .database(let id, _):
            return id == sessionID
        }
    }

    /// Returns true if the given database on the given session is within this scope.
    func includes(sessionID: UUID, databaseName: String) -> Bool {
        switch self {
        case .allServers:
            return true
        case .server(let id):
            return id == sessionID
        case .database(let id, let db):
            return id == sessionID && db.caseInsensitiveCompare(databaseName) == .orderedSame
        }
    }
}

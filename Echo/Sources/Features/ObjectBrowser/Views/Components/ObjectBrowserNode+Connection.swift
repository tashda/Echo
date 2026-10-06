import Foundation

extension ObjectBrowserNode.Row {
    /// The server session a row belongs to, or `nil` for rows that carry none (spacers,
    /// pending connections, columns, placeholders).
    @MainActor
    var session: ConnectionSession? {
        switch self {
        case .server(let session),
             .database(let session, _),
             .object(let session, _, _),
             .action(let session, _, _),
             .dock(let session, _, _):
            return session
        case .section(let folder), .folder(let folder):
            return folder.session
        case .item(let row):
            return row.session
        case .topSpacer, .pendingConnection, .column, .placeholder, .loading, .message, .filter:
            return nil
        }
    }

    /// The connection a row belongs to, or `nil` for rows that carry no connection
    /// (spacers, columns, informational leaves).
    @MainActor
    var connectionID: UUID? {
        if case .pendingConnection(let pending) = self { return pending.connection.id }
        return session?.connection.id
    }

    /// The database a row belongs to, when the row carries one directly.
    @MainActor
    var databaseName: String? {
        switch self {
        case .database(_, let database):
            return database.name
        case .object(_, let databaseName, _):
            return databaseName
        case .section(let folder), .folder(let folder):
            return folder.databaseName
        case .item(let row):
            return row.databaseName
        default:
            return nil
        }
    }

    @MainActor
    var isServerHeader: Bool {
        if case .server = self { return true }
        return false
    }
}

/// What sits at the top of the Explorer's visible area (the shared tree layout works it out).
typealias ObjectBrowserTopVisibleContext = ExplorerTreeTopContext

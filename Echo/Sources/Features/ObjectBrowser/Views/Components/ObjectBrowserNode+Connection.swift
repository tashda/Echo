import Foundation

extension ObjectBrowserNode.Row {
    /// The connection a row belongs to, or `nil` for rows that carry no connection
    /// (spacers, columns, informational leaves).
    @MainActor
    var connectionID: UUID? {
        switch self {
        case .pendingConnection(let pending):
            return pending.connection.id
        case .server(let session),
             .databasesFolder(let session, _),
             .database(let session, _, _),
             .objectGroup(let session, _, _, _),
             .object(let session, _, _),
             .serverFolder(let session, _, _),
             .databaseFolder(let session, _, _, _, _),
             .databaseSubfolder(let session, _, _, _, _, _),
             .databaseNamedItem(let session, _, _, _, _, _),
             .securitySection(let session, _, _, _),
             .securityLogin(let session, _),
             .securityServerRole(let session, _),
             .securityCredential(let session, _),
             .agentJob(let session, _),
             .databaseSnapshot(let session, _),
             .linkedServer(let session, _),
             .ssisFolder(let session, _),
             .serverTrigger(let session, _),
             .action(let session, _, _):
            return session.connection.id
        case .topSpacer, .column, .infoLeaf, .loading, .message:
            return nil
        }
    }
}

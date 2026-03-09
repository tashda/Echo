import SwiftUI

extension ManageConnectionsView {
    func handleFoldersChange(_ oldFolders: [SavedFolder], _ newFolders: [SavedFolder]) {
        pruneNavigationStacks()

        if let pendingConnection = pendingConnectionMove,
           newFolders.count > oldFolders.count,
           let newFolder = newFolders.first(where: { folder in
               !oldFolders.contains(where: { $0.id == folder.id }) && folder.kind == .connections
           }) {
            moveConnectionToFolder(pendingConnection, newFolder)
            pendingConnectionMove = nil
        }

        if let pendingIdentity = pendingIdentityMove,
           newFolders.count > oldFolders.count,
           let newFolder = newFolders.first(where: { folder in
               !oldFolders.contains(where: { $0.id == folder.id }) && folder.kind == .identities
           }) {
            moveIdentityToFolder(pendingIdentity, newFolder)
            pendingIdentityMove = nil
        }
    }

    func handleConnectionDrop(items: [String], folder: SavedFolder) -> Bool {
        guard folder.kind == .connections else { return false }

        guard let firstItem = items.first,
              firstItem.hasPrefix("connection:"),
              let connectionID = UUID(uuidString: String(firstItem.dropFirst("connection:".count))),
              let connection = projectConnections.first(where: { $0.id == connectionID }) else {
            return false
        }

        moveConnectionToFolder(connection, folder)
        return true
    }

    func handleIdentityDrop(items: [String], folder: SavedFolder) -> Bool {
        guard folder.kind == .identities else { return false }

        guard let firstItem = items.first,
              firstItem.hasPrefix("identity:"),
              let identityID = UUID(uuidString: String(firstItem.dropFirst("identity:".count))),
              let identity = projectIdentities.first(where: { $0.id == identityID }) else {
            return false
        }

        moveIdentityToFolder(identity, folder)
        return true
    }
}

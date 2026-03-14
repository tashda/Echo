import SwiftUI

extension ManageConnectionsView {
    func currentFolder(for section: ManageSection) -> SavedFolder? {
        if case .folder(let id, let selectedSection) = sidebarSelection,
           selectedSection == section {
            return folder(withID: id)
        }
        if let folderID = connectionStore.selectedFolderID,
           let folder = folder(withID: folderID),
           folder.kind.manageSection == section {
            return folder
        }
        return nil
    }

    func defaultFolder(for section: ManageSection) -> SavedFolder? {
        guard let projectID = selectedProjectID else { return nil }

        switch section {
        case .connections:
            if let folderID = connectionStore.selectedFolderID,
               let folder = folder(withID: folderID),
               folder.projectID == projectID,
               folder.kind == .connections {
                return folder
            }
            if let connectionID = connectionStore.selectedConnectionID,
               let connection = projectConnections.first(where: { $0.id == connectionID }),
               let folderID = connection.folderID,
               let folder = folder(withID: folderID) {
                return folder
            }
        case .identities:
            if let folderID = connectionStore.selectedFolderID,
               let folder = folder(withID: folderID),
               folder.projectID == projectID,
               folder.kind == .identities {
                return folder
            }
            if let identityID = connectionStore.selectedIdentityID,
               let identity = projectIdentities.first(where: { $0.id == identityID }),
               let folderID = identity.folderID,
               let folder = folder(withID: folderID) {
                return folder
            }
        case .projects:
            return nil
        }
        return nil
    }

    func moveConnectionToFolder(_ connection: SavedConnection, _ folder: SavedFolder) {
        guard let index = connectionStore.connections.firstIndex(where: { $0.id == connection.id }) else { return }
        connectionStore.connections[index].folderID = folder.id
        Task { @MainActor in
            try? await connectionStore.saveConnections()
        }
    }

    func createFolderAndMoveConnection(_ connection: SavedConnection) {
        pendingConnectionMove = connection
        let parent = currentFolder(for: .connections)
        folderEditorState = .create(kind: .connections, parent: parent, token: UUID())
    }

    func moveIdentityToFolder(_ identity: SavedIdentity, _ folder: SavedFolder) {
        guard let index = connectionStore.identities.firstIndex(where: { $0.id == identity.id }) else { return }
        connectionStore.identities[index].folderID = folder.id
        Task { @MainActor in
            try? await connectionStore.saveIdentities()
        }
    }

    func createFolderAndMoveIdentity(_ identity: SavedIdentity) {
        pendingIdentityMove = identity
        let parent = currentFolder(for: .identities)
        folderEditorState = .create(kind: .identities, parent: parent, token: UUID())
    }
}

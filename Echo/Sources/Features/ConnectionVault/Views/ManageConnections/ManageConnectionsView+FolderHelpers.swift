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
        }
        return nil
    }

    func moveConnectionToFolder(_ connection: SavedConnection, _ folder: SavedFolder) {
        var updatedConnection = connection
        updatedConnection.folderID = folder.id
        Task {
            await environmentState.upsertConnection(updatedConnection, password: nil)
        }
    }

    func createFolderAndMoveConnection(_ connection: SavedConnection) {
        pendingConnectionMove = connection
        let parent = currentFolder(for: .connections)
        folderEditorState = .create(kind: .connections, parent: parent, token: UUID())
    }

    func moveIdentityToFolder(_ identity: SavedIdentity, _ folder: SavedFolder) {
        var updatedIdentity = identity
        updatedIdentity.folderID = folder.id
        Task {
            try? await connectionStore.updateIdentity(updatedIdentity)
        }
    }

    func createFolderAndMoveIdentity(_ identity: SavedIdentity) {
        pendingIdentityMove = identity
        let parent = currentFolder(for: .identities)
        folderEditorState = .create(kind: .identities, parent: parent, token: UUID())
    }
}

import SwiftUI

extension FolderKind {
    var manageSection: ManageSection {
        switch self {
        case .connections: return .connections
        case .identities: return .identities
        }
    }
}

extension ManageSection {
    var folderKind: FolderKind? {
        switch self {
        case .connections: return .connections
        case .identities: return .identities
        case .projects: return nil
        }
    }
}

extension ManageConnectionsView {
    func handleConnectionEditorSave(
        connection: SavedConnection,
        password: String?,
        action: ConnectionEditorView.SaveAction
    ) {
        Task {
            await environmentState.upsertConnection(connection, password: password)

            await MainActor.run {
                selectedSection = .connections
                connectionStore.selectedFolderID = connection.folderID
                connectionSelection = [connection.id]
                connectionEditorPresentation = nil
            }

            if action == .saveAndConnect {
                environmentState.connect(to: connection)
                closeManageConnections()
            }
        }
    }

    func handleDeletion(_ payload: DeletionTarget) {
        pendingDeletion = payload
    }

    func performDeletion(for target: DeletionTarget) {
        switch target {
        case .connection(let connection):
            Task { await environmentState.deleteConnection(connection) }
        case .folder(let folder):
            Task { try? await connectionStore.deleteFolder(folder) }
        case .identity(let identity):
            Task { try? await connectionStore.deleteIdentity(identity) }
        }
        pendingDeletion = nil
    }

    func createNewConnection() {
        connectionEditorPresentation = ConnectionEditorPresentation(connection: nil)
    }

    func editConnection(_ connection: SavedConnection) {
        connectionEditorPresentation = ConnectionEditorPresentation(connection: connection)
    }

    func duplicateConnection(_ connection: SavedConnection) {
        pendingDuplicateConnection = connection
    }

    func performDuplicate(_ connection: SavedConnection, copyBookmarks: Bool) {
        Task {
            pendingDuplicateConnection = nil
            var duplicated = connection
            duplicated.id = UUID()
            duplicated.connectionName = "\(connection.connectionName) (Copy)"

            try? await connectionStore.updateConnection(duplicated)

            if copyBookmarks, let projectID = connection.projectID,
               var project = projectStore.projects.first(where: { $0.id == projectID }) {
                let existingBookmarks = environmentState.bookmarkRepository.bookmarks(for: connection.id, in: project)
                for var bookmark in existingBookmarks {
                    bookmark.id = UUID()
                    bookmark.connectionID = duplicated.id
                    environmentState.bookmarkRepository.addBookmark(bookmark, to: &project)
                }
                await projectStore.saveProject(project)
            }
        }
    }

    func connectToConnection(_ connection: SavedConnection) {
        environmentState.connect(to: connection)
        closeManageConnections()
    }

    func closeManageConnections() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    func createNewIdentity() {
        selectedSection = .identities
        let parent = currentFolder(for: .identities)
        identityEditorState = .create(parent: parent, token: UUID())
    }

    func createNewFolder(for section: ManageSection, parent: SavedFolder? = nil) {
        guard let kind = section.folderKind else { return }
        folderEditorState = .create(kind: kind, parent: parent, token: UUID())
    }

    func presentCreateFolder(for section: ManageSection) {
        let parent = currentFolder(for: section)
        createNewFolder(for: section, parent: parent)
    }

    func editIdentity(_ identity: SavedIdentity) {
        identityEditorState = .edit(identity: identity)
    }

    func editFolder(_ folder: SavedFolder) {
        folderEditorState = .edit(folder: folder)
    }

}

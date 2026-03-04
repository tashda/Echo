import SwiftUI

extension ManageConnectionsView {
    func handlePrimaryAdd(for section: ManageSection) {
        switch section {
        case .connections:
            createNewConnection()
        case .identities:
            createNewIdentity()
        }
    }

    func handleSectionChange(_ section: ManageSection) {
        searchText = ""
        if section == .connections {
            connectionStore.selectedIdentityID = nil
        }

        let target: SidebarSelection = .section(section)
        if sidebarSelection != target {
            sidebarSelection = target
        }
    }

    func handleSidebarSelectionChange(_ selection: SidebarSelection?) {
        guard let selection else { return }

        if selectedSection != selection.section {
            selectedSection = selection.section
        }

        switch selection {
        case .section:
            if connectionStore.selectedFolderID != nil {
                connectionStore.selectedFolderID = nil
            }
        case .folder(let folderID, _):
            if connectionStore.selectedFolderID != folderID {
                connectionStore.selectedFolderID = folderID
            }
        }
    }

    func syncSidebarSelection(withFolderID folderID: UUID?) {
        guard let folderID,
              let folder = folder(withID: folderID) else {
            let section = selectedSection ?? .connections
            let target: SidebarSelection = .section(section)
            if sidebarSelection != target {
                sidebarSelection = target
            }
            return
        }

        let section = folder.kind.manageSection
        if selectedSection != section {
            selectedSection = section
        }

        let target: SidebarSelection = .folder(folder.id, section)
        if sidebarSelection != target {
            sidebarSelection = target
        }
    }

    func pruneConnectionSelection(allowedIDs: Set<UUID>) {
        let invalid = connectionSelection.filter { !allowedIDs.contains($0) }
        if !invalid.isEmpty {
            connectionSelection.subtract(invalid)
        }
    }

    func pruneIdentitySelection(allowedIDs: Set<UUID>) {
        let invalid = identitySelection.filter { !allowedIDs.contains($0) }
        if !invalid.isEmpty {
            identitySelection.subtract(invalid)
        }
    }

    func resetForProjectChange() {
        searchText = ""
        pendingDeletion = nil
        connectionEditorPresentation = nil
        folderEditorState = nil
        identityEditorState = nil
        connectionSelection.removeAll()
        identitySelection.removeAll()
        selectedSection = .connections
        sidebarSelection = .section(.connections)
        pruneNavigationStacks()
        ensureSectionSelection()
    }

    func pruneNavigationStacks() {
        guard let projectID = selectedProjectID else {
            connectionStore.selectedFolderID = nil
            connectionStore.selectedIdentityID = nil
            connectionStore.selectedConnectionID = nil
            return
        }

        if let folderID = connectionStore.selectedFolderID,
           !connectionStore.folders.contains(where: { $0.id == folderID && $0.projectID == projectID }) {
            connectionStore.selectedFolderID = nil
        }

        if let identityID = connectionStore.selectedIdentityID,
           !connectionStore.identities.contains(where: { $0.id == identityID && $0.projectID == projectID }) {
            connectionStore.selectedIdentityID = nil
        }

        if let connectionID = connectionStore.selectedConnectionID,
           !connectionStore.connections.contains(where: { $0.id == connectionID && $0.projectID == projectID }) {
            connectionStore.selectedConnectionID = nil
        }

        syncSidebarSelection(withFolderID: connectionStore.selectedFolderID)
    }

    func ensureSectionSelection() {
        if selectedSection == nil {
            if let identityID = connectionStore.selectedIdentityID,
               connectionStore.identities.contains(where: { $0.id == identityID }) {
                selectedSection = .identities
            } else {
                selectedSection = .connections
            }
        }

        if sidebarSelection == nil {
            if let folderID = connectionStore.selectedFolderID {
                syncSidebarSelection(withFolderID: folderID)
            } else if let section = selectedSection {
                sidebarSelection = .section(section)
            } else {
                sidebarSelection = .section(.connections)
            }
        }

        if connectionSelection.isEmpty,
           let id = connectionStore.selectedConnectionID,
           filteredConnectionsForTable.contains(where: { $0.id == id }) {
            connectionSelection = [id]
        }

        if identitySelection.isEmpty,
           let id = connectionStore.selectedIdentityID,
           filteredIdentitiesForTable.contains(where: { $0.id == id }) {
            identitySelection = [id]
        }
    }

    func handleConnectionEditorSave(
        connection: SavedConnection,
        password: String?,
        action: ConnectionEditorView.SaveAction
    ) {
        Task {
            await workspaceSessionStore.upsertConnection(connection, password: password)

            await MainActor.run {
                selectedSection = .connections
                connectionStore.selectedFolderID = connection.folderID
                connectionSelection = [connection.id]
                connectionEditorPresentation = nil
            }

            if action == .saveAndConnect {
                await workspaceSessionStore.connect(to: connection)
                await MainActor.run {
                    closeManageConnections()
                }
            }
        }
    }

    func handleDeletion(_ payload: DeletionTarget) {
        pendingDeletion = payload
    }

    func performDeletion(for target: DeletionTarget) {
        switch target {
        case .connection(let connection):
            Task { await workspaceSessionStore.deleteConnection(connection) }
        case .folder(let folder):
            Task { try? await connectionStore.deleteFolder(folder) }
        case .identity(let identity):
            Task { try? await connectionStore.deleteIdentity(identity) }
        }
        pendingDeletion = nil
    }

    func createNewConnection() {
        selectedSection = .connections
        let parent = currentFolder(for: .connections) ?? defaultFolder(for: .connections)
        connectionStore.selectedFolderID = parent?.id
        connectionEditorPresentation = ConnectionEditorPresentation(connection: nil)
    }

    func editConnection(_ connection: SavedConnection) {
        selectedSection = .connections
        connectionStore.selectedFolderID = connection.folderID
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
                let existingBookmarks = workspaceSessionStore.bookmarkRepository.bookmarks(for: connection.id, in: project)
                for var bookmark in existingBookmarks {
                    bookmark.id = UUID()
                    bookmark.connectionID = duplicated.id
                    workspaceSessionStore.bookmarkRepository.addBookmark(bookmark, to: &project)
                }
                await projectStore.saveProject(project)
            }
        }
    }

    func connectToConnection(_ connection: SavedConnection) {
        Task {
            await workspaceSessionStore.connect(to: connection)
            await MainActor.run {
                closeManageConnections()
            }
        }
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
        let parent = currentFolder(for: .identities) ?? defaultFolder(for: .identities)
        identityEditorState = .create(parent: parent, token: UUID())
    }

    func createNewFolder(for section: ManageSection, parent: SavedFolder? = nil) {
        folderEditorState = .create(kind: section.folderKind, parent: parent, token: UUID())
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
            await workspaceSessionStore.upsertConnection(updatedConnection, password: nil)
        }
    }

    func createFolderAndMoveConnection(_ connection: SavedConnection) {
        pendingConnectionMove = connection
        let parent = currentFolder(for: .connections)
        folderEditorState = .create(kind: .connections, parent: parent, token: UUID())
    }

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

private extension FolderKind {
    var manageSection: ManageSection {
        switch self {
        case .connections: return .connections
        case .identities: return .identities
        }
    }
}

private extension ManageSection {
    var folderKind: FolderKind {
        switch self {
        case .connections: return .connections
        case .identities: return .identities
        }
    }
}

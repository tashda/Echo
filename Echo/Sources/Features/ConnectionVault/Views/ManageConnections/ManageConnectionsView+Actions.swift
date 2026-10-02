import SwiftUI

extension ManageConnectionsView {
    // MARK: - Moving with unsaved changes (MC1)

    /// Goes where asked, unless the editor has unsaved changes: then asks Save, Don't Save or Cancel.
    func navigate(to target: PendingNavigation) {
        if isCurrent(target) { return }
        if detailHasChanges {
            pendingNavigation = target
        } else {
            apply(target)
        }
    }

    private func isCurrent(_ target: PendingNavigation) -> Bool {
        switch target {
        case .connections(let ids): ids == connectionSelection
        case .identities(let ids): ids == identitySelection && !isCreatingIdentity
        case .scope(let newScope): newScope == activeScope
        case .newConnection: isCreatingConnection
        case .newIdentity: isCreatingIdentity
        }
    }

    func apply(_ target: PendingNavigation) {
        detailHasChanges = false
        detailSaveBlocker = nil
        if target != .newConnection { isCreatingConnection = false }
        switch target {
        case .connections(let ids):
            connectionSelection = ids
        case .identities(let ids):
            isCreatingIdentity = false
            identitySelection = ids
        case .scope(let newScope):
            isCreatingIdentity = false
            scope = newScope
        case .newConnection:
            if !activeScope.isConnections { scope = .allConnections }
            connectionSelection = []
            isCreatingConnection = true
            editorRevision += 1
        case .newIdentity:
            if activeScope.isConnections { scope = .identities }
            identitySelection = []
            isCreatingIdentity = true
        }
    }

    /// "Save changes to “postgres18”?", or "Discard changes to …?" when they can't be saved yet.
    var leaveAlertTitle: String {
        let verb = detailSaveBlocker == nil ? "Save" : "Discard"
        if isCreatingConnection { return "\(verb) the new connection?" }
        if activeScope.isConnections, let id = connectionSelection.first,
           let connection = connectionStore.connections.first(where: { $0.id == id }) {
            return "\(verb) changes to “\(displayName(for: connection))”?"
        }
        if !activeScope.isConnections, !isCreatingIdentity, let id = identitySelection.first,
           let identity = connectionStore.identities.first(where: { $0.id == id }) {
            return "\(verb) changes to “\(identity.name)”?"
        }
        return isCreatingIdentity ? "\(verb) the new identity?" : "\(verb) your changes?"
    }

    func saveThenContinue() {
        navigationAfterSave = pendingNavigation
        pendingNavigation = nil
        saveRequest += 1
    }

    func discardThenContinue() {
        guard let target = pendingNavigation else { return }
        pendingNavigation = nil
        editorRevision += 1
        apply(target)
    }

    /// After a save: rebuild the editor from the saved values, then go where the alert was going.
    private func finishSave() {
        detailHasChanges = false
        editorRevision += 1
        if let target = navigationAfterSave {
            navigationAfterSave = nil
            apply(target)
        }
    }

    // MARK: - Saving

    func handleConnectionEditorSave(connection: SavedConnection, password: String?, action: ConnectionEditorView.SaveAction) {
        Task {
            await environmentState.upsertConnection(connection, password: password)
            await MainActor.run {
                if navigationAfterSave == nil { connectionSelection = [connection.id] }
                finishSave()
            }
            if action == .saveAndConnect {
                environmentState.connect(to: connection)
                closeManageConnections()
            }
        }
    }

    /// R2-B: the new connection made in the pane is saved, filed in the folder on show.
    func handleNewConnectionSave(connection: SavedConnection, password: String?, action: ConnectionEditorView.SaveAction) {
        var connection = connection
        if connection.folderID == nil, case .folder(let folderID) = activeScope { connection.folderID = folderID }
        let saved = connection
        Task {
            await environmentState.upsertConnection(saved, password: password)
            await MainActor.run {
                isCreatingConnection = false
                if navigationAfterSave == nil { connectionSelection = [saved.id] }
                finishSave()
            }
        }
    }

    func cancelNewConnection() {
        isCreatingConnection = false
        detailHasChanges = false
        detailSaveBlocker = nil
        editorRevision += 1
    }

    func handleIdentitySaved(_ identity: SavedIdentity) {
        isCreatingIdentity = false
        if navigationAfterSave == nil { identitySelection = [identity.id] }
        finishSave()
    }

    // MARK: - Connections

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

    func duplicateConnection(_ connection: SavedConnection) {
        pendingDuplicateConnection = connection
    }

    func performDuplicate(_ connection: SavedConnection, copyBookmarks: Bool) {
        Task {
            pendingDuplicateConnection = nil
            var duplicated = connection
            duplicated.id = UUID()
            duplicated.connectionName = "\(displayName(for: connection)) copy"

            try? await connectionStore.updateConnection(duplicated)
            await MainActor.run { apply(.connections([duplicated.id])) }

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

    func deleteConnections(_ connections: [SavedConnection]) {
        Task {
            for connection in connections {
                await environmentState.deleteConnection(connection)
            }
            await MainActor.run {
                connectionSelection.removeAll()
                detailHasChanges = false
            }
        }
    }

    // MARK: - Deleting

    /// Says what depends on what is deleted.
    func deletionMessage(for target: DeletionTarget) -> String {
        switch target {
        case .connection:
            return "Its saved password and settings are removed. This can't be undone."
        case .identity(let identity):
            let users = connections(using: identity)
            switch users.count {
            case 0: return "No connection signs in with it. This can't be undone."
            case 1: return "\(displayName(for: users[0])) signs in with it and will ask for a password until you choose another sign-in."
            default: return "\(users.count) connections sign in with it. They will ask for a password until you choose another sign-in."
            }
        }
    }

    func performDeletion(for target: DeletionTarget) {
        switch target {
        case .connection(let connection):
            Task { await environmentState.deleteConnection(connection) }
            connectionSelection.remove(connection.id)
        case .identity(let identity):
            Task { try? await connectionStore.deleteIdentity(identity) }
            identitySelection.remove(identity.id)
        }
        detailHasChanges = false
        pendingDeletion = nil
    }

    // MARK: - Projects

    func resetForProjectChange() {
        searchText = ""
        pendingDeletion = nil
        pendingNavigation = nil
        navigationAfterSave = nil
        isCreatingIdentity = false
        isCreatingConnection = false
        detailHasChanges = false
        collapsedGroupIDs.removeAll()
        connectionSelection.removeAll()
        identitySelection.removeAll()
    }
}

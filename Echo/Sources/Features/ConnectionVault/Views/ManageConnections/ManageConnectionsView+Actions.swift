import SwiftUI

extension ManageConnectionsView {
    func handlePrimaryAdd(for section: ManageSection) {
        switch section {
        case .connections:
            createNewConnection()
        case .identities:
            createNewIdentity()
        case .projects:
            isPresentingNewProjectSheet = true
        }
    }

    func handleSectionChange(_ section: ManageSection) {
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

        if sidebarSelection != selection {
            sidebarSelection = selection
        }

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
        case .project:
            if connectionStore.selectedFolderID != nil {
                connectionStore.selectedFolderID = nil
            }
        }
    }

    func syncSidebarSelection(withFolderID folderID: UUID?) {
        guard let folderID,
              let folder = folder(withID: folderID) else {
            // If we're currently selecting a project, don't reset to the section level
            // just because the folder selection was cleared.
            if case .project = sidebarSelection {
                return
            }

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

        // Preserve current selection if it's a project
        if case .project(let projectID) = sidebarSelection {
            if !projectStore.projects.contains(where: { $0.id == projectID }) {
                selectedSection = .connections
                sidebarSelection = .section(.connections)
            }
        } else {
            selectedSection = .connections
            sidebarSelection = .section(.connections)
        }

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

    func importSettingsFromProject(_ source: Project, into targetID: UUID) {
        isImportingSettings = true
        lastImportedFrom = nil
        Task {
            try? await projectStore.importProjectResources(
                from: source,
                into: targetID,
                connectionStore: connectionStore,
                merge: true,
                includeSettings: true,
                connectionIDs: Set(connectionStore.connections.filter { $0.projectID == source.id }.map(\.id)),
                identityIDs: Set(connectionStore.identities.filter { $0.projectID == source.id }.map(\.id))
            )
            await MainActor.run {
                isImportingSettings = false
                lastImportedFrom = (name: source.name, date: Date())
            }
        }
    }

}

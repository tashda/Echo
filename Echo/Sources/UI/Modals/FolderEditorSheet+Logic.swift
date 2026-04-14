import SwiftUI

extension FolderEditorSheet {

    // MARK: - Logic

    func handleCredentialModeChange(_ newMode: FolderCredentialMode) {
        if newMode == .manual {
            manualUsername = editingFolderUsesManual ? (editingFolder?.manualUsername ?? "") : ""
            manualPassword = ""
            manualPasswordDirty = false
        } else if newMode == .identity && selectedIdentityID == nil {
            selectedIdentityID = availableIdentities.first?.id
        } else {
            manualUsername = ""
            manualPassword = ""
            manualPasswordDirty = false
        }
    }

    func prepareInitialValues() {
        if case .edit(let folder) = state {
            name = folder.name
            folderDescription = folder.folderDescription ?? ""
            selectedColorHex = folder.colorHex
            selectedIcon = folder.icon
            selectedKind = folder.kind
            selectedParentID = folder.parentFolderID
            credentialMode = folder.credentialMode
            selectedIdentityID = folder.identityID
            manualUsername = folder.manualUsername ?? ""
            manualPassword = ""
            manualPasswordDirty = false
        } else if case .create(let kind, let parent, _) = state {
            name = ""
            folderDescription = ""
            selectedColorHex = FolderIdentityPalette.defaults.first ?? "5A9CDE"
            selectedIcon = SavedFolder.defaultIcon
            selectedKind = kind
            selectedParentID = parent?.id
            credentialMode = .none
            selectedIdentityID = nil
            if let parent {
                selectedColorHex = parent.colorHex
                if parent.credentialMode == .inherit { credentialMode = .inherit }
            }
            manualUsername = ""
            manualPassword = ""
            manualPasswordDirty = false
        }
    }

    func saveFolder() async {
        var folder: SavedFolder
        switch state {
        case .create:
            folder = SavedFolder(name: name)
            folder.id = UUID()
            folder.projectID = projectStore.selectedProject?.id
        case .edit(let existing):
            folder = existing
            folder.name = name
        }

        let trimmedDescription = folderDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        folder.folderDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        folder.icon = selectedIcon
        folder.colorHex = selectedColorHex
        folder.kind = selectedKind
        folder.parentFolderID = selectedParentID
        folder.credentialMode = isIdentityFolder ? .none : credentialMode
        folder.identityID = credentialMode == .identity && !isIdentityFolder ? selectedIdentityID : nil
        folder.manualUsername = credentialMode == .manual && !isIdentityFolder ? manualUsername.trimmingCharacters(in: .whitespacesAndNewlines) : nil

        let pw = (credentialMode == .manual && !isIdentityFolder && manualPasswordDirty) ? manualPassword.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        if let pw { try? environmentState.identityRepository.setPassword(pw, for: &folder) }

        let isNew = !isEditing
        try? await connectionStore.updateFolder(folder)
        if isNew && folder.kind == .connections { connectionStore.selectedFolderID = folder.id }
        dismiss()
    }
}

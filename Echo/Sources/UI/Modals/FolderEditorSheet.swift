import SwiftUI

struct FolderEditorSheet: View {
    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(EnvironmentState.self) var environmentState
    @Environment(\.dismiss) var dismiss

    let state: FolderEditorState

    @State var name: String = ""
    @State var folderDescription: String = ""
    @State var selectedColorHex: String = FolderIdentityPalette.defaults.first ?? "5A9CDE"
    @State var selectedIcon: String = SavedFolder.defaultIcon
    @State var selectedKind: FolderKind = .connections
    @State var selectedParentID: UUID?
    @State var credentialMode: FolderCredentialMode = .none
    @State var selectedIdentityID: UUID?
    @State var manualUsername: String = ""
    @State var manualPassword: String = ""
    @State var manualPasswordDirty = false
    @State var identityEditorState: IdentityEditorState?

    var editingFolder: SavedFolder? {
        if case .edit(let folder) = state { return folder }
        return nil
    }

    var isEditing: Bool { editingFolder != nil }

    var isIdentityFolder: Bool { selectedKind == .identities }

    var selectedParentFolder: SavedFolder? {
        guard let id = selectedParentID else { return nil }
        return connectionStore.folders.first(where: { $0.id == id })
    }

    var inheritedIdentity: SavedIdentity? {
        guard let parent = selectedParentFolder else { return nil }
        return environmentState.identityRepository.resolveInheritedIdentity(folderID: parent.id)
    }

    var editingFolderUsesManual: Bool { editingFolder?.credentialMode == .manual }

    var availableIdentities: [SavedIdentity] {
        connectionStore.identities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var availableParentFolders: [SavedFolder] {
        let projectID = projectStore.selectedProject?.id
        let editingID = editingFolder?.id
        return connectionStore.folders
            .filter { $0.kind == selectedKind && $0.projectID == projectID && $0.id != editingID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func folderPath(for folder: SavedFolder) -> String {
        var components: [String] = [folder.name]
        var current = folder
        while let parentID = current.parentFolderID,
              let parent = connectionStore.folders.first(where: { $0.id == parentID }) {
            components.insert(parent.name, at: 0)
            current = parent
        }
        return components.joined(separator: " / ")
    }

    var hierarchicalParentFolders: [(folder: SavedFolder, path: String)] {
        availableParentFolders.map { folder in
            (folder: folder, path: folderPath(for: folder))
        }
        .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    var folderColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: selectedColorHex) ?? ColorTokens.accent },
            set: { color in selectedColorHex = color.toHex() ?? selectedColorHex }
        )
    }

    var canUseInheritance: Bool {
        guard let parent = selectedParentFolder else { return false }
        return parent.credentialMode != .none
    }

    var hasDuplicateName: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        let projectID = projectStore.selectedProject?.id
        let siblings = connectionStore.folders.filter {
            $0.kind == selectedKind
            && $0.projectID == projectID
            && $0.parentFolderID == selectedParentID
            && $0.id != editingFolder?.id
        }
        return siblings.contains {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return false }
        if hasDuplicateName { return false }
        switch credentialMode {
        case .manual:
            let trimmedUser = manualUsername.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedUser.isEmpty { return false }
            return (editingFolderUsesManual && !manualPasswordDirty) || !manualPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .identity: return selectedIdentityID != nil
        default: return true
        }
    }

    var availableIcons: [String] {
        isIdentityFolder ? FolderIdentityPalette.identityIcons : FolderIdentityPalette.connectionIcons
    }

    var body: some View {
        SheetLayout(
            title: isEditing ? "Edit Folder" : "New Folder",
            icon: selectedIcon,
            subtitle: isEditing ? "Modify folder settings and credentials." : "Create a folder to organize your connections.",
            primaryAction: isEditing ? "Save" : "Create",
            canSubmit: isValid,
            onSubmit: { await saveFolder() },
            onCancel: { dismiss() },
            destructiveAction: isEditing ? "Delete" : nil,
            onDestructive: isEditing ? {
                if let folder = editingFolder {
                    Task { try? await connectionStore.deleteFolder(folder); dismiss() }
                }
            } : nil
        ) {
            formContent
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .sheet(item: $identityEditorState) { state in
            IdentityEditorSheet(state: state) { identity in
                selectedIdentityID = identity.id
                credentialMode = .identity
            }
            .environment(projectStore)
            .environment(connectionStore)
            .environment(environmentState)
        }
        .onAppear(perform: prepareInitialValues)
    }
}

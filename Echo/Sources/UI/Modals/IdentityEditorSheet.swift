import SwiftUI

struct IdentityEditorSheet: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @Environment(\.dismiss) private var dismiss

    let state: IdentityEditorState
    var onSave: ((SavedIdentity) -> Void)? = nil

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var passwordDirty = false
    @State private var selectedFolderID: UUID?

    private var editingIdentity: SavedIdentity? {
        if case .edit(let identity) = state { return identity }
        return nil
    }

    private var isEditing: Bool { editingIdentity != nil }

    private var editingIdentityHasPassword: Bool {
        guard let identity = editingIdentity else { return false }
        return identity.keychainIdentifier != nil
    }

    private var availableFolders: [SavedFolder] {
        connectionStore.folders
            .filter { $0.kind == .identities && $0.projectID == projectStore.selectedProject?.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func folderPath(for folder: SavedFolder) -> String {
        var components: [String] = [folder.name]
        var current = folder
        while let parentID = current.parentFolderID,
              let parent = connectionStore.folders.first(where: { $0.id == parentID }) {
            components.insert(parent.name, at: 0)
            current = parent
        }
        return components.joined(separator: " / ")
    }

    private var hierarchicalFolders: [(folder: SavedFolder, path: String)] {
        availableFolders.map { folder in
            (folder: folder, path: folderPath(for: folder))
        }
        .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    private var hasDuplicateName: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        let projectID = projectStore.selectedProject?.id
        let siblings = connectionStore.identities.filter {
            $0.projectID == projectID
            && $0.folderID == selectedFolderID
            && $0.id != editingIdentity?.id
        }
        return siblings.contains {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedUsername.isEmpty { return false }
        if hasDuplicateName { return false }
        if !isEditing && password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footerButtons
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: prepareInitialValues)
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            Section {
                TextField("Name", text: $name, prompt: Text("Production"))
                if hasDuplicateName {
                    Text("An identity with this name already exists here.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.red)
                }
            } header: {
                Text(isEditing ? "Edit Identity" : "New Identity")
            }

            Section("Credentials") {
                TextField("Username", text: $username, prompt: Text("db_admin"))
                SecureField("Password", text: Binding(
                    get: { password },
                    set: { password = $0; passwordDirty = true }
                ), prompt: Text("••••••••"))
                if isEditing && editingIdentityHasPassword && !passwordDirty {
                    Text("Existing password will be kept unless changed.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Location") {
                Picker("Folder", selection: $selectedFolderID) {
                    Text("None").tag(UUID?.none)
                    ForEach(hierarchicalFolders, id: \.folder.id) { item in
                        Text(item.path).tag(UUID?.some(item.folder.id))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack {
            if let identity = editingIdentity {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await connectionStore.deleteIdentity(identity)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            Spacer()

            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button(isEditing ? "Save" : "Create") {
                Task { await saveIdentity() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
        }
        .padding(SpacingTokens.md2)
    }

    // MARK: - Logic

    private func prepareInitialValues() {
        if case .edit(let identity) = state {
            name = identity.name
            username = identity.username
            selectedFolderID = identity.folderID
            password = ""
            passwordDirty = false
        } else if case .create(let parent, _) = state {
            name = ""
            username = ""
            password = ""
            passwordDirty = false
            selectedFolderID = parent?.id
        }
    }

    private func saveIdentity() async {
        var identity: SavedIdentity

        switch state {
        case .create:
            identity = SavedIdentity(
                projectID: projectStore.selectedProject?.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                keychainIdentifier: "echo.identity.\(UUID().uuidString)",
                folderID: selectedFolderID
            )
        case .edit(let existing):
            identity = existing
            identity.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            identity.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
            identity.folderID = selectedFolderID
            identity.updatedAt = Date()
        }

        if passwordDirty && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try? environmentState.identityRepository.setPassword(password, for: &identity)
        } else if !isEditing {
            try? environmentState.identityRepository.setPassword(password, for: &identity)
        }

        try? await connectionStore.updateIdentity(identity)
        onSave?(identity)
        dismiss()
    }
}

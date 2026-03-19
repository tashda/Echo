import SwiftUI

struct IdentityEditorSheet: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.dismiss) private var dismiss

    let state: IdentityEditorState
    var onSave: ((SavedIdentity) -> Void)? = nil

    @State private var name: String = ""
    @State private var authenticationMethod: DatabaseAuthenticationMethod = .sqlPassword
    @State private var username: String = ""
    @State private var domain: String = ""
    @State private var password: String = ""
    @State private var passwordDirty = false
    @State private var selectedFolderID: UUID?
    @State private var isSaving = false

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
        if isSaving { return false }
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
        if trimmedName.isEmpty { return false }
        if hasDuplicateName { return false }

        if authenticationMethod.usesAccessToken {
            // Access token: need the token (stored in password field), no username required
            if !isEditing && password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        } else {
            // SQL Password / Windows Integrated: need username + password
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedUsername.isEmpty { return false }
            if !isEditing && password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        }

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
                PropertyRow(title: "Name") {
                    TextField("", text: $name, prompt: Text("Production"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                
                if hasDuplicateName {
                    Text("An identity with this name already exists here.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .listRowSeparator(.hidden)
                }
            } header: {
                Text(isEditing ? "Edit Identity" : "New Identity")
            }

            Section("Credentials") {
                PropertyRow(title: "Authentication") {
                    Picker("", selection: $authenticationMethod) {
                        ForEach(DatabaseAuthenticationMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if authenticationMethod.usesAccessToken {
                    PropertyRow(title: "Access Token") {
                        SecureField("", text: Binding(
                            get: { password },
                            set: { password = $0; passwordDirty = true }
                        ), prompt: Text(isEditing && editingIdentityHasPassword && !passwordDirty
                            ? "••••••••"
                            : "JWT access token"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                    }
                } else {
                    if authenticationMethod.requiresDomain {
                        PropertyRow(title: "Domain") {
                            TextField("", text: $domain, prompt: Text("DOMAIN"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    PropertyRow(title: "Username") {
                        TextField("", text: $username, prompt: Text("db_admin"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "Password") {
                        SecureField("", text: Binding(
                            get: { password },
                            set: { password = $0; passwordDirty = true }
                        ), prompt: Text(isEditing && editingIdentityHasPassword && !passwordDirty
                            ? "••••••••"
                            : (authenticationMethod == .windowsIntegrated ? "Windows password" : "••••••••")))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                    }
                }

                if isEditing && editingIdentityHasPassword && !passwordDirty {
                    Text("Existing password will be kept unless changed.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .listRowSeparator(.hidden)
                }
            }

            Section("Location") {
                PropertyRow(title: "Folder") {
                    Picker("", selection: $selectedFolderID) {
                        Text("None").tag(UUID?.none)
                        ForEach(hierarchicalFolders, id: \.folder.id) { item in
                            Text(item.path).tag(UUID?.some(item.folder.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
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
                .buttonStyle(.bordered)
                .tint(ColorTokens.Status.error)
            }

            Spacer()

            Button("Cancel", role: .cancel) { dismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

            Button(isEditing ? "Save" : "Create") {
                Task { await saveIdentity() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
        }
        .padding(SpacingTokens.md)
    }

    // MARK: - Logic

    private func prepareInitialValues() {
        if case .edit(let identity) = state {
            name = identity.name
            authenticationMethod = identity.authenticationMethod
            username = identity.username
            domain = identity.domain ?? ""
            selectedFolderID = identity.folderID
            password = ""
            passwordDirty = false
        } else if case .create(let parent, _) = state {
            name = ""
            authenticationMethod = .sqlPassword
            username = ""
            domain = ""
            password = ""
            passwordDirty = false
            selectedFolderID = parent?.id
        }
    }

    private func saveIdentity() async {
        isSaving = true
        var identity: SavedIdentity

        let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)

        switch state {
        case .create:
            identity = SavedIdentity(
                projectID: projectStore.selectedProject?.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                authenticationMethod: authenticationMethod,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                domain: trimmedDomain.isEmpty ? nil : trimmedDomain,
                keychainIdentifier: "echo.identity.\(UUID().uuidString)",
                folderID: selectedFolderID
            )
        case .edit(let existing):
            identity = existing
            identity.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            identity.authenticationMethod = authenticationMethod
            identity.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
            identity.domain = trimmedDomain.isEmpty ? nil : trimmedDomain
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

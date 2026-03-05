import SwiftUI

struct IdentityEditorSheet: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearanceStore: AppearanceStore

    let state: IdentityEditorState
    var onSave: ((SavedIdentity) -> Void)? = nil

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var selectedFolderID: UUID?

    private var editingIdentity: SavedIdentity? {
        if case .edit(let identity) = state { return identity }
        return nil
    }

    private var availableFolders: [SavedFolder] {
        connectionStore.folders
            .filter { $0.kind == .identities }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingIdentity == nil ? "New Identity" : "Edit Identity")
                .font(.system(size: 22, weight: .semibold))

            Divider()

            identityForm

            Divider()

            footerButtons
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, 18)
        .frame(width: 420)
        .background(ColorTokens.Background.primary)
        .onAppear(perform: prepareInitialValues)
    }

    private var identityForm: some View {
        Form {
            Section {
                LabeledContent("Name") {
                    TextField("", text: $name, prompt: Text("Production"))
                }

                LabeledContent("Username") {
                    TextField("", text: $username, prompt: Text("db_admin"))
                }

                LabeledContent("Password") {
                    SecureField("", text: $password, prompt: Text("••••••••"))
                }
            } header: {
                Text("Identity Details")
            }

            if !availableFolders.isEmpty {
                Section {
                    LabeledContent("Folder") {
                        Picker("", selection: Binding<UUID?>(
                            get: { selectedFolderID },
                            set: { selectedFolderID = $0 }
                        )) {
                            Text("No Folder").tag(UUID?.none)
                            ForEach(availableFolders, id: \.id) { folder in
                                Text(folder.name).tag(UUID?.some(folder.id))
                            }
                        }
                        .labelsHidden()
                    }
                } header: {
                    Text("Location")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxHeight: 320)
    }

    @ViewBuilder
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
                Spacer()
            } else {
                Spacer()
            }

            Button("Cancel", role: .cancel) { dismiss() }

            Button(editingIdentity == nil ? "Create" : "Save") {
                Task { await saveIdentity() }
            }
            .buttonStyle(.borderedProminent)
            .tint(appearanceStore.accentColor)
            .disabled(!isValid)
        }
        .controlSize(.regular)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func prepareInitialValues() {
        if case .edit(let identity) = state {
            name = identity.name
            username = identity.username
            selectedFolderID = identity.folderID
        } else if selectedFolderID == nil,
                  let first = availableFolders.first {
            selectedFolderID = first.id
        }
    }

    private func saveIdentity() async {
        var identity: SavedIdentity

        switch state {
        case .create:
            identity = SavedIdentity(
                projectID: projectStore.selectedProject?.id,
                name: name,
                username: username,
                keychainIdentifier: "echo.identity.\(UUID().uuidString)",
                folderID: selectedFolderID
            )
        case .edit(let existing):
            identity = existing
            identity.name = name
            identity.username = username
            identity.folderID = selectedFolderID
        }

        if !password.isEmpty {
            try? environmentState.identityRepository.setPassword(password, for: &identity)
        }
        try? await connectionStore.updateIdentity(identity)
        onSave?(identity)
        dismiss()
    }
}

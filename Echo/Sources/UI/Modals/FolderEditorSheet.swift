import SwiftUI

struct FolderEditorSheet: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearanceStore: AppearanceStore

    let state: FolderEditorState

    @State private var name: String = ""
    @State private var selectedColorHex: String = FolderIdentityPalette.defaults.first ?? "BAF2BB"
    @State private var credentialMode: FolderCredentialMode = .none
    @State private var selectedIdentityID: UUID?
    @State private var manualUsername: String = ""
    @State private var manualPassword: String = ""
    @State private var manualPasswordDirty = false
    @State private var identityEditorState: IdentityEditorState?

    private var isIdentityFolder: Bool {
        switch state {
        case .create(let kind, _, _): return kind == .identities
        case .edit(let folder): return folder.kind == .identities
        }
    }

    private var parentFolder: SavedFolder? {
        switch state {
        case .create(_, let parent, _): return parent
        case .edit(let folder):
            guard let parentID = folder.parentFolderID else { return nil }
            return connectionStore.folders.first(where: { $0.id == parentID })
        }
    }

    private var editingFolder: SavedFolder? {
        if case .edit(let folder) = state { return folder }
        return nil
    }

    private var inheritedIdentity: SavedIdentity? {
        guard let parent = parentFolder else { return nil }
        return environmentState.identityRepository.resolveInheritedIdentity(folderID: parent.id)
    }

    private var editingFolderUsesManual: Bool { editingFolder?.credentialMode == .manual }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(editingFolder == nil ? "New Folder" : "Edit Folder").font(.system(size: 22, weight: .semibold))
            Text(editingFolder == nil ? "Group connections and share credentials across team members." : "Update folder details and credential sharing preferences.").font(TypographyTokens.standard).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var availableIdentities: [SavedIdentity] {
        connectionStore.identities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var folderColorBinding: Binding<Color> {
        Binding(get: { Color(hex: selectedColorHex) ?? .accentColor }, set: { color in selectedColorHex = color.toHex() ?? selectedColorHex })
    }

    private var canUseInheritance: Bool { guard let parent = parentFolder else { return false }; return parent.credentialMode != .none }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return false }
        switch credentialMode {
        case .manual:
            let trimmedUser = manualUsername.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedUser.isEmpty { return false }
            return (editingFolderUsesManual && !manualPasswordDirty) || !manualPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .identity: return selectedIdentityID != nil
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            header; Divider(); formContent; Divider(); footerButtons
        }
        .padding(.horizontal, SpacingTokens.md2).padding(.vertical, 18).frame(width: 520).background(ColorTokens.Background.primary)
        .sheet(item: $identityEditorState) { state in
            IdentityEditorSheet(state: state) { identity in selectedIdentityID = identity.id; credentialMode = .identity }
                .environment(projectStore).environment(connectionStore).environmentObject(environmentState)
        }
        .onAppear(perform: prepareInitialValues)
    }

    private var formContent: some View {
        Form {
            Section {
                LabeledContent("Folder Name") { TextField("", text: $name, prompt: Text("Folder name")) }
                LabeledContent("Color") { colorPaletteView }
            } header: { Text("Folder Details") }
            if !isIdentityFolder { credentialsFormSection }
        }
        .formStyle(.grouped).scrollContentBackground(.hidden).frame(maxHeight: 360)
        .onChange(of: credentialMode) { _, newMode in handleCredentialModeChange(newMode) }
    }

    @ViewBuilder
    private var credentialsFormSection: some View {
        Section {
            Picker("Credential Mode", selection: $credentialMode) {
                Text("None").tag(FolderCredentialMode.none); Text("Manual").tag(FolderCredentialMode.manual); Text("Link Identity").tag(FolderCredentialMode.identity)
                if canUseInheritance { Text("Inherit Parent").tag(FolderCredentialMode.inherit) }
            }.pickerStyle(.segmented)
            switch credentialMode {
            case .manual:
                LabeledContent("Username") { TextField("", text: $manualUsername, prompt: Text("shared_user")) }
                LabeledContent("Password") {
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("", text: Binding(get: { manualPassword }, set: { manualPassword = $0; manualPasswordDirty = true }), prompt: Text("••••••••"))
                        if editingFolderUsesManual && !manualPasswordDirty { Text("Existing password retained").font(.footnote).foregroundStyle(.secondary) }
                    }
                }
            case .identity: identitySelectionContent
            case .inherit:
                if let identity = inheritedIdentity { Text("This folder will inherit the identity '\(identity.name)' from its parent.").foregroundStyle(.secondary).font(.callout) }
                else { Text("Parent folder does not provide credentials to inherit.").foregroundStyle(.red).font(.callout) }
            case .none: EmptyView()
            }
        } header: { Text("Credentials") }
    }

    private var identitySelectionContent: some View {
        Group {
            if availableIdentities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No identities available.").foregroundStyle(.secondary).font(.callout)
                    HStack { Spacer(); Button("Create Linked Identity…") { identityEditorState = .create(parent: nil, token: UUID()) }.buttonStyle(.link) }
                }
            } else {
                LabeledContent("Identity") {
                    Picker("", selection: $selectedIdentityID) {
                        Text("Select Identity").tag(UUID?.none)
                        ForEach(availableIdentities, id: \.id) { Text($0.name).tag(UUID?.some($0.id)) }
                    }.labelsHidden()
                }
                HStack { Spacer(); Button("Create Linked Identity…") { identityEditorState = .create(parent: nil, token: UUID()) }.buttonStyle(.link) }
            }
        }
    }

    private var colorPaletteView: some View {
        HStack(spacing: 10) {
            ForEach(FolderIdentityPalette.defaults, id: \.self) { hex in
                let swatch = Color(hex: hex) ?? .accentColor
                Circle().fill(swatch).frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(Color.white.opacity(selectedColorHex == hex ? 0.9 : 0.25), lineWidth: 2))
                    .overlay(Circle().strokeBorder(swatch.opacity(selectedColorHex == hex ? 0.75 : 0.0), lineWidth: selectedColorHex == hex ? 3 : 0))
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { selectedColorHex = hex } }
            }
            ColorPicker("", selection: folderColorBinding).labelsHidden().frame(width: 24, height: 24)
        }.frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private var footerButtons: some View {
        HStack {
            if let folder = editingFolder {
                Button(role: .destructive) { Task { try? await connectionStore.deleteFolder(folder); dismiss() } } label: { Label("Delete Folder", systemImage: "trash") }.buttonStyle(.borderedProminent).tint(.red)
            }
            Spacer(); Button("Cancel", role: .cancel) { dismiss() }
            Button(editingFolder == nil ? "Create Folder" : "Save Changes") { Task { await saveFolder() } }.buttonStyle(.borderedProminent).tint(appearanceStore.accentColor).disabled(!isValid)
        }.controlSize(.regular)
    }

    private func handleCredentialModeChange(_ newMode: FolderCredentialMode) {
        if newMode == .manual { manualUsername = editingFolderUsesManual ? (editingFolder?.manualUsername ?? "") : ""; manualPassword = ""; manualPasswordDirty = false }
        else if newMode == .identity && selectedIdentityID == nil { selectedIdentityID = availableIdentities.first?.id }
        else { manualUsername = ""; manualPassword = ""; manualPasswordDirty = false }
    }

    private func prepareInitialValues() {
        if case .edit(let folder) = state { name = folder.name; selectedColorHex = folder.colorHex; credentialMode = folder.credentialMode; selectedIdentityID = folder.identityID; manualUsername = folder.manualUsername ?? ""; manualPassword = ""; manualPasswordDirty = false }
        else { if let parent = parentFolder { selectedColorHex = parent.colorHex; if parent.credentialMode == .inherit { credentialMode = .inherit } }; manualUsername = ""; manualPassword = ""; manualPasswordDirty = false }
    }

    private func saveFolder() async {
        var folder: SavedFolder
        switch state {
        case .create(let kind, let parent, _): folder = SavedFolder(name: name); folder.id = UUID(); folder.projectID = projectStore.selectedProject?.id; folder.parentFolderID = parent?.id; folder.kind = kind
        case .edit(let existing): folder = existing; folder.name = name
        }
        folder.colorHex = selectedColorHex; folder.credentialMode = credentialMode; folder.identityID = credentialMode == .identity ? selectedIdentityID : nil
        folder.manualUsername = credentialMode == .manual ? manualUsername.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        let pw = (credentialMode == .manual && manualPasswordDirty) ? manualPassword.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        if let pw { try? environmentState.identityRepository.setPassword(pw, for: &folder) }
        try? await connectionStore.updateFolder(folder); if folder.kind == .connections { connectionStore.selectedFolderID = folder.id }; dismiss()
    }
}

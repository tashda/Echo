import SwiftUI

struct FolderEditorSheet: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.dismiss) private var dismiss

    let state: FolderEditorState

    @State private var name: String = ""
    @State private var folderDescription: String = ""
    @State private var selectedColorHex: String = FolderIdentityPalette.defaults.first ?? "5A9CDE"
    @State private var selectedIcon: String = SavedFolder.defaultIcon
    @State private var selectedKind: FolderKind = .connections
    @State private var selectedParentID: UUID?
    @State private var credentialMode: FolderCredentialMode = .none
    @State private var selectedIdentityID: UUID?
    @State private var manualUsername: String = ""
    @State private var manualPassword: String = ""
    @State private var manualPasswordDirty = false
    @State private var identityEditorState: IdentityEditorState?

    private var editingFolder: SavedFolder? {
        if case .edit(let folder) = state { return folder }
        return nil
    }

    private var isEditing: Bool { editingFolder != nil }

    private var isIdentityFolder: Bool { selectedKind == .identities }

    private var selectedParentFolder: SavedFolder? {
        guard let id = selectedParentID else { return nil }
        return connectionStore.folders.first(where: { $0.id == id })
    }

    private var inheritedIdentity: SavedIdentity? {
        guard let parent = selectedParentFolder else { return nil }
        return environmentState.identityRepository.resolveInheritedIdentity(folderID: parent.id)
    }

    private var editingFolderUsesManual: Bool { editingFolder?.credentialMode == .manual }

    private var availableIdentities: [SavedIdentity] {
        connectionStore.identities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableParentFolders: [SavedFolder] {
        let projectID = projectStore.selectedProject?.id
        let editingID = editingFolder?.id
        return connectionStore.folders
            .filter { $0.kind == selectedKind && $0.projectID == projectID && $0.id != editingID }
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

    private var hierarchicalParentFolders: [(folder: SavedFolder, path: String)] {
        availableParentFolders.map { folder in
            (folder: folder, path: folderPath(for: folder))
        }
        .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    private var folderColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: selectedColorHex) ?? ColorTokens.accent },
            set: { color in selectedColorHex = color.toHex() ?? selectedColorHex }
        )
    }

    private var canUseInheritance: Bool {
        guard let parent = selectedParentFolder else { return false }
        return parent.credentialMode != .none
    }

    private var hasDuplicateName: Bool {
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

    private var isValid: Bool {
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

    private var availableIcons: [String] {
        isIdentityFolder ? FolderIdentityPalette.identityIcons : FolderIdentityPalette.connectionIcons
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footerButtons
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

    // MARK: - Form

    private var formContent: some View {
        Form {
            Section {
                PropertyRow(title: "Name") {
                    TextField("", text: $name, prompt: Text("Folder name"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                
                if hasDuplicateName {
                    Text("A folder with this name already exists here.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .listRowSeparator(.hidden)
                }
                
                PropertyRow(title: "Description") {
                    TextField("", text: $folderDescription, prompt: Text("Optional"), axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .multilineTextAlignment(.trailing)
                }
                
                PropertyRow(title: "Icon") { iconPaletteView }
                PropertyRow(title: "Color") { colorPaletteView }
            } header: {
                Text(isEditing ? "Edit Folder" : "New Folder")
            }

            Section("Location") {
                PropertyRow(title: "Type") {
                    Picker("", selection: $selectedKind) {
                        Text("Connections").tag(FolderKind.connections)
                        Text("Identities").tag(FolderKind.identities)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(title: "Parent") {
                    Picker("", selection: $selectedParentID) {
                        Text("None").tag(UUID?.none)
                        ForEach(hierarchicalParentFolders, id: \.folder.id) { item in
                            Text(item.path).tag(UUID?.some(item.folder.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            if !isIdentityFolder {
                credentialsFormSection
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .onChange(of: credentialMode) { _, newMode in handleCredentialModeChange(newMode) }
        .onChange(of: selectedKind) { _, _ in
            selectedParentID = nil
            selectedIcon = SavedFolder.defaultIcon
            if selectedKind == .identities {
                credentialMode = .none
            }
        }
    }

    // MARK: - Icon Palette

    private var iconPaletteView: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            ForEach(availableIcons, id: \.self) { iconName in
                iconSwatch(name: iconName, isSelected: selectedIcon == iconName)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedIcon = iconName
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func iconSwatch(name: String, isSelected: Bool) -> some View {
        Image(systemName: name)
            .font(TypographyTokens.prominent)
            .frame(width: 26, height: 26)
            .foregroundStyle(isSelected ? Color.white : ColorTokens.Text.secondary)
            .background(isSelected ? ColorTokens.accent : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }

    // MARK: - Color Palette

    private var colorPaletteView: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(FolderIdentityPalette.defaults, id: \.self) { hex in
                let swatch = Color(hex: hex) ?? ColorTokens.accent
                colorSwatch(color: swatch, isSelected: selectedColorHex == hex)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedColorHex = hex }
                    }
            }

            ColorPicker("", selection: folderColorBinding, supportsOpacity: false)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func colorSwatch(color: Color, isSelected: Bool) -> some View {
        Circle().fill(color).frame(width: SpacingTokens.md2, height: SpacingTokens.md2)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(TypographyTokens.label.weight(.bold))
                        .foregroundStyle(Color.white)
                }
            }
            .overlay(Circle().strokeBorder(ColorTokens.Text.primary.opacity(0.15), lineWidth: 0.5))
            .contentShape(Circle())
    }

    // MARK: - Credentials

    @ViewBuilder
    private var credentialsFormSection: some View {
        Section("Credentials") {
            PropertyRow(title: "Mode") {
                Picker("", selection: $credentialMode) {
                    Text("None").tag(FolderCredentialMode.none)
                    Text("Manual").tag(FolderCredentialMode.manual)
                    Text("Identity").tag(FolderCredentialMode.identity)
                    if canUseInheritance { Text("Inherit").tag(FolderCredentialMode.inherit) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            switch credentialMode {
            case .manual:
                PropertyRow(title: "Username") {
                    TextField("", text: $manualUsername, prompt: Text("shared_user"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                
                PropertyRow(title: "Password") {
                    SecureField("", text: Binding(
                        get: { manualPassword },
                        set: { manualPassword = $0; manualPasswordDirty = true }
                    ), prompt: Text("••••••••"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                }
                
                if editingFolderUsesManual && !manualPasswordDirty {
                    Text("Existing password will be kept unless changed.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .listRowSeparator(.hidden)
                }
            case .identity:
                identitySelectionContent
            case .inherit:
                if let identity = inheritedIdentity {
                    Text("Inherits identity \"\(identity.name)\" from parent folder.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .font(TypographyTokens.formDescription)
                        .listRowSeparator(.hidden)
                } else {
                    Text("Parent folder does not provide credentials.")
                        .foregroundStyle(ColorTokens.Status.error)
                        .font(TypographyTokens.formDescription)
                        .listRowSeparator(.hidden)
                }
            case .none:
                EmptyView()
            }
        }
    }

    private var identitySelectionContent: some View {
        Group {
            if availableIdentities.isEmpty {
                PropertyRow(title: "Identity") {
                    VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                        Text("No identities available.")
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .font(TypographyTokens.formDescription)
                        Button("Create Identity") {
                            identityEditorState = .create(parent: nil, token: UUID())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            } else {
                PropertyRow(title: "Identity") {
                    HStack(spacing: SpacingTokens.xs) {
                        Picker("", selection: $selectedIdentityID) {
                            Text("Select").tag(UUID?.none)
                            ForEach(availableIdentities, id: \.id) {
                                Text($0.name).tag(UUID?.some($0.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        
                        Button {
                            identityEditorState = .create(parent: nil, token: UUID())
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Add identity")
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack {
            if let folder = editingFolder {
                Button("Delete", role: .destructive) {
                    Task { try? await connectionStore.deleteFolder(folder); dismiss() }
                }
                .buttonStyle(.bordered)
                .tint(ColorTokens.Status.error)
            }

            Spacer()

            Button("Cancel", role: .cancel) { dismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

            Button(isEditing ? "Save" : "Create") { Task { await saveFolder() } }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
        }
        .padding(SpacingTokens.md)
    }

    // MARK: - Logic

    private func handleCredentialModeChange(_ newMode: FolderCredentialMode) {
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

    private func prepareInitialValues() {
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

    private func saveFolder() async {
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

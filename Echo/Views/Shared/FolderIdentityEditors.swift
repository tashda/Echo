import SwiftUI

// MARK: - Shared Folder & Identity Management Types

enum DeletionTarget: Identifiable {
    case connection(SavedConnection)
    case folder(SavedFolder)
    case identity(SavedIdentity)

    var id: UUID {
        switch self {
        case .connection(let connection):
            return connection.id
        case .folder(let folder):
            return folder.id
        case .identity(let identity):
            return identity.id
        }
    }

    var displayName: String {
        switch self {
        case .connection(let connection):
            return connection.connectionName
        case .folder(let folder):
            return folder.name
        case .identity(let identity):
            return identity.name
        }
    }
}

enum FolderEditorState: Identifiable {
    case create(kind: FolderKind, parent: SavedFolder?, token: UUID)
    case edit(folder: SavedFolder)

    var id: UUID {
        switch self {
        case .create(_, _, let token):
            return token
        case .edit(let folder):
            return folder.id
        }
    }
}

enum IdentityEditorState: Identifiable {
    case create(parent: SavedFolder?, token: UUID)
    case edit(identity: SavedIdentity)

    var id: UUID {
        switch self {
        case .create(_, let token):
            return token
        case .edit(let identity):
            return identity.id
        }
    }
}

struct FolderEditorSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let state: FolderEditorState

    @State private var name: String = ""
    @State private var selectedColorHex: String = FolderIdentityPalette.defaults.first ?? "BAF2BB"
    @State private var credentialMode: FolderCredentialMode = .none
    @State private var selectedIdentityID: UUID?

    private var isIdentityFolder: Bool {
        switch state {
        case .create(let kind, _, _):
            return kind == .identities
        case .edit(let folder):
            return folder.kind == .identities
        }
    }

    private var parentFolder: SavedFolder? {
        switch state {
        case .create(_, let parent, _):
            return parent
        case .edit(let folder):
            guard let parentID = folder.parentFolderID else { return nil }
            return appModel.folders.first(where: { $0.id == parentID })
        }
    }

    private var editingFolder: SavedFolder? {
        if case .edit(let folder) = state { return folder }
        return nil
    }

    private var availableIdentities: [SavedIdentity] {
        appModel.identities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var folderColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: selectedColorHex) ?? .accentColor },
            set: { color in selectedColorHex = color.toHex() ?? selectedColorHex }
        )
    }

    private var canUseInheritance: Bool {
        guard let parent = parentFolder else { return false }
        return parent.credentialMode != .none
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingFolder == nil ? "New Folder" : "Edit Folder")
                .font(.title3)
                .fontWeight(.semibold)

            folderForm

            if !isIdentityFolder {
                credentialsSection
            }

            Spacer()

            footerButtons
        }
        .padding(24)
        .frame(width: 420)
        .onAppear(perform: prepareInitialValues)
    }

    private var folderForm: some View {
        FormSection {
            FormRow(label: "Folder Name") {
                TextEntryField(text: $name, placeholder: "Folder name")
            }

            FormRow(label: "Color", showsDivider: false) {
                HStack(spacing: 10) {
                    ForEach(FolderIdentityPalette.defaults, id: \.self) { hex in
                        let swatchColor = Color(hex: hex) ?? .accentColor
                        Circle()
                            .fill(swatchColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(selectedColorHex == hex ? 0.9 : 0.3), lineWidth: 2)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        swatchColor.opacity(selectedColorHex == hex ? 0.8 : 0.0),
                                        lineWidth: selectedColorHex == hex ? 3 : 0
                                    )
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedColorHex = hex
                                }
                            }
                    }
                    ColorPicker("", selection: folderColorBinding)
                        .labelsHidden()
                        .frame(width: 24, height: 24)
                }
            }
        }
    }

    private var credentialsSection: some View {
        FormSection(title: "Credentials") {
            FormRow(label: "Mode", showsDivider: credentialMode == .identity) {
                Picker("", selection: $credentialMode) {
                    Text("None").tag(FolderCredentialMode.none)
                    Text("Link Identity").tag(FolderCredentialMode.identity)
                    if canUseInheritance {
                        Text("Inherit Parent").tag(FolderCredentialMode.inherit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }

            if credentialMode == .identity {
                FormRow(label: "Identity", showsDivider: false) {
                    Picker("", selection: Binding<UUID?>(
                        get: { selectedIdentityID },
                        set: { selectedIdentityID = $0 }
                    )) {
                        Text("Select Identity").tag(UUID?.none)
                        ForEach(availableIdentities, id: \.id) { identity in
                            Text(identity.name).tag(UUID?.some(identity.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        HStack {
            if editingFolder != nil {
                Button("Delete", role: .destructive) {
                    guard let folder = editingFolder else { return }
                    Task {
                        await appModel.deleteFolder(folder)
                        dismiss()
                    }
                }
                Spacer()
            } else {
                Spacer()
            }

            Button("Cancel", role: .cancel) { dismiss() }

            Button(editingFolder == nil ? "Create" : "Save") {
                Task { await saveFolder() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
        }
    }

    private func prepareInitialValues() {
        if case .edit(let folder) = state {
            name = folder.name
            selectedColorHex = folder.colorHex
            credentialMode = folder.credentialMode
            selectedIdentityID = folder.identityID
        } else {
            if let parent = parentFolder {
                selectedColorHex = parent.colorHex
            }
        }
    }

    private func saveFolder() async {
        var folder: SavedFolder

        switch state {
        case .create(let kind, let parent, _):
            folder = SavedFolder(name: name)
            folder.id = UUID()
            folder.projectID = appModel.selectedProject?.id
            folder.parentFolderID = parent?.id
            folder.kind = kind
        case .edit(let existing):
            folder = existing
            folder.name = name
        }

        folder.colorHex = selectedColorHex
        folder.credentialMode = credentialMode
        folder.identityID = credentialMode == .identity ? selectedIdentityID : nil

        await appModel.upsertFolder(folder)
        if folder.kind == .connections {
            appModel.selectedFolderID = folder.id
        }
        dismiss()
    }
}

struct IdentityEditorSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

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
        appModel.folders
            .filter { $0.kind == .identities }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(editingIdentity == nil ? "New Identity" : "Edit Identity")
                .font(.title3)
                .fontWeight(.semibold)

            formContent

            Spacer()

            footerButtons
        }
        .padding(24)
        .frame(width: 420)
        .onAppear(perform: prepareInitialValues)
    }

    private var formContent: some View {
        Form {
            Section("Identity") {
                LabeledContent("Name") {
                    TextField("", text: $name, prompt: Text("Production"))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Username") {
                    TextField("", text: $username, prompt: Text("db_admin"))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Password") {
                    SecureField("", text: $password, prompt: Text("••••••••"))
                        .multilineTextAlignment(.trailing)
                }
            }

            if !availableFolders.isEmpty {
                Section("Folder") {
                    LabeledContent("Location") {
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
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var footerButtons: some View {
        HStack {
            if let identity = editingIdentity {
                Button("Delete", role: .destructive) {
                    Task {
                        await appModel.deleteIdentity(identity)
                        dismiss()
                    }
                }
                Spacer()
            } else {
                Spacer()
            }

            Button("Cancel", role: .cancel) { dismiss() }

            Button(editingIdentity == nil ? "Create" : "Save") {
                Task { await saveIdentity() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
        }
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
        }
    }

    private func saveIdentity() async {
        var identity: SavedIdentity

        switch state {
        case .create:
            identity = SavedIdentity(
                projectID: appModel.selectedProject?.id,
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

        await appModel.upsertIdentity(identity, password: password.isEmpty ? nil : password)
        onSave?(identity)
        dismiss()
    }
}

// MARK: - Modern Form Helpers

private struct FormSection<Content: View>: View {
    private let title: String?
    private let contentBuilder: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.contentBuilder = content
    }

    private let cornerRadius: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                contentBuilder()
            }
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.6)
            )
        }
    }
}

private struct FormRow<Content: View>: View {
    let label: String
    var showsDivider: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 120, alignment: .leading)

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)

            if showsDivider {
                FormDivider()
            }
        }
    }
}

private struct FormDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 132)
    }
}

private struct TextEntryField: View {
    @Binding var text: String
    let placeholder: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.tertiary))
            .textFieldStyle(.plain)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(inputBackground)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.35 : 0.12), lineWidth: 1)
            )
    }
}

private struct SecureEntryField: View {
    @Binding var text: String
    let placeholder: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(.tertiary))
            .textFieldStyle(.plain)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(inputBackground)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.35 : 0.12), lineWidth: 1)
            )
    }
}

enum FolderIdentityPalette {
    static let defaults: [String] = [
        "BAF2BB",
        "BAF2D8",
        "BAD7F2",
        "F2BAC9",
        "F2E2BA"
    ]
}

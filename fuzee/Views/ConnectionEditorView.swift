import SwiftUI

struct ConnectionEditorView: View {
    enum SaveAction {
        case save
        case saveAndConnect
    }

    static let colorPalette: [String] = [
        "BAF2BB",
        "BAF2D8",
        "BAD7F2",
        "F2BAC9",
        "F2E2BA"
    ]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var model: SavedConnection
    @State private var password: String
    @State private var isTestingConnection = false
    @State private var testResult: ConnectionTestResult?
    @State private var testTask: Task<Void, Never>?

    let onSave: (SavedConnection, String?, SaveAction) -> Void
    private let isEditingExisting: Bool

    init(connection: SavedConnection?, onSave: @escaping (SavedConnection, String?, SaveAction) -> Void) {
        self.onSave = onSave
        self.isEditingExisting = connection != nil

        var initialModel = connection ?? SavedConnection(
            connectionName: "",
            host: "",
            port: DatabaseType.postgresql.defaultPort,
            database: "",
            username: "",
            credentialSource: .manual,
            identityID: nil,
            keychainIdentifier: nil,
            useTLS: true,
            databaseType: .postgresql,
            serverVersion: nil,
            colorHex: ConnectionEditorView.colorPalette.first ?? "",
            cachedStructure: nil,
            cachedStructureUpdatedAt: nil
        )

        if initialModel.colorHex.isEmpty {
            initialModel.colorHex = ConnectionEditorView.colorPalette.first ?? ""
        }

        _model = State(initialValue: initialModel)
        _password = State(initialValue: "")
    }

    private var normalizedSelectedColorHex: String {
        model.colorHex.uppercased()
    }

    private var sortedFolders: [SavedFolder] {
        appModel.folders
            .filter { $0.kind == .connections }
            .sorted { lhs, rhs in
            folderDisplayName(lhs).localizedCaseInsensitiveCompare(folderDisplayName(rhs)) == .orderedAscending
        }
    }

    private var sortedIdentities: [SavedIdentity] {
        appModel.identities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedIdentity: SavedIdentity? {
        guard let identityID = model.identityID else { return nil }
        return sortedIdentities.first { $0.id == identityID }
    }

    private var inheritedIdentity: SavedIdentity? {
        guard let folderID = model.folderID else { return nil }
        return appModel.folderIdentity(for: folderID)
    }

    private var isFormValid: Bool {
        let trimmedName = model.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = model.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDatabase = model.database.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = model.username.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasValidPort = (1...65535).contains(model.port)
        let requiresDatabase = model.databaseType != .sqlite

        let credentialsValid: Bool
        switch model.credentialSource {
        case .manual:
            credentialsValid = !trimmedUsername.isEmpty
        case .identity:
            credentialsValid = model.identityID != nil
        case .inherit:
            credentialsValid = model.folderID != nil && inheritedIdentity != nil
        }

        if trimmedName.isEmpty || trimmedHost.isEmpty || !hasValidPort {
            return false
        }

        if requiresDatabase && trimmedDatabase.isEmpty {
            return false
        }

        return credentialsValid
    }

    private var testButtonLabel: some View {
        HStack(spacing: 6) {
            if isTestingConnection {
                ProgressView().controlSize(.small)
                Text("Cancel Test")
            } else {
                Image(systemName: "link.badge.plus")
                Text("Test Configuration")
            }
        }
    }

    private var databaseTypeSelection: Binding<DatabaseType?> {
        Binding<DatabaseType?>(
            get: { model.databaseType },
            set: { newValue in
                guard let newValue else { return }
                updateDatabaseType(newValue)
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            databaseTypeList
        } detail: {
            editorContent
        }
        .frame(minWidth: 820, minHeight: 600)
        .onDisappear { cancelActiveTest() }
        .onAppear {
            if !isEditingExisting, model.folderID == nil {
                model.folderID = appModel.selectedFolderID
            }
        }
        .onChange(of: model.credentialSource) { _, newSource in
            switch newSource {
            case .manual:
                break
            case .identity:
                password = ""
                if appModel.identities.isEmpty {
                    model.identityID = nil
                } else if let identityID = model.identityID,
                          appModel.identities.contains(where: { $0.id == identityID }) {
                    // Keep current identity
                } else {
                    model.identityID = appModel.identities.first?.id
                }
            case .inherit:
                password = ""
            }
        }
        .onChange(of: appModel.identities) { _, newIdentities in
            guard model.credentialSource == .identity else { return }
            if let identityID = model.identityID,
               !newIdentities.contains(where: { $0.id == identityID }) {
                model.identityID = newIdentities.first?.id
            } else if model.identityID == nil {
                model.identityID = newIdentities.first?.id
            }
        }
        .onChange(of: appModel.folders) { _, newFolders in
            if let folderID = model.folderID,
               !newFolders.contains(where: { $0.id == folderID }) {
                model.folderID = nil
            }
        }
    }

    private var databaseTypeList: some View {
        List(DatabaseType.allCases, id: \.self, selection: databaseTypeSelection) { type in
            databaseTypeRow(for: type)
        }
        .listStyle(.sidebar)
        .navigationTitle("Database Type")
    }

    private func databaseTypeRow(for type: DatabaseType) -> some View {
        Label(type.displayName, systemImage: type.iconName)
            .font(.system(size: 14, weight: .medium))
            .padding(.vertical, 4)
            .tag(type)
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    GroupBox("Connection Identity", content: identitySection)
                    GroupBox("Server", content: serverSection)
                    GroupBox("Placement", content: folderSection)
                    GroupBox("Authentication", content: authenticationSection)
                    GroupBox("Security", content: securitySection)

                    if let result = testResult {
                        ConnectionTestResultView(result: result)
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.vertical, 32)
                .padding(.horizontal, 40)
            }

            Divider()

            actionButtons
        }
        .navigationTitle(model.connectionName.isEmpty ? "New Connection" : model.connectionName)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button(action: handleTestButton) {
                testButtonLabel
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!isTestingConnection && !isFormValid)

            Button("Save") {
                handleSave(action: .save)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isFormValid)

            Button("Save & Connect") {
                handleSave(action: .saveAndConnect)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isFormValid)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: normalizedSelectedColorHex) ?? .accentColor)
                    .frame(width: 68, height: 68)

                Image(systemName: model.databaseType.iconName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle((Color(hex: normalizedSelectedColorHex) ?? .accentColor).contrastingForegroundColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.connectionName.isEmpty ? "Untitled Connection" : model.connectionName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(model.databaseType.displayName)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    private func identitySection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Name", text: $model.connectionName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(Self.colorPalette, id: \.self) { hex in
                        PaletteColorSwatch(
                            hex: hex,
                            isSelected: normalizedSelectedColorHex == hex.uppercased()
                        ) {
                            model.colorHex = hex.uppercased()
                        }
                    }
                }
            }
        }
    }

    private func serverSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Server Address", text: $model.host)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                TextField(
                    "Port",
                    value: $model.port,
                    format: .number.grouping(.never)
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)

                Text("Default: \(model.databaseType.defaultPort)")
                    .foregroundStyle(.secondary)
            }

            TextField("Database", text: $model.database)
                .textFieldStyle(.roundedBorder)
                .disabled(model.databaseType == .sqlite)
                .opacity(model.databaseType == .sqlite ? 0.5 : 1.0)
        }
    }

    private func folderSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(
                "Folder",
                selection: Binding<UUID?>(
                    get: { model.folderID },
                    set: { model.folderID = $0 }
                )
            ) {
                Text("No Folder").tag(UUID?.none)
                ForEach(sortedFolders, id: \.id) { folder in
                    Text(folderDisplayName(folder)).tag(UUID?.some(folder.id))
                }
            }
            .pickerStyle(.menu)

            if let folderID = model.folderID,
               let folder = appModel.folders.first(where: { $0.id == folderID }) {
                folderSummaryView(for: folder)
            } else {
                Text("Connections without a folder appear at the root level.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func authenticationSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Credentials", selection: $model.credentialSource) {
                ForEach(CredentialSource.allCases, id: \.self) { source in
                    Text(source.displayName).tag(source)
                }
            }
            .pickerStyle(.segmented)

            switch model.credentialSource {
            case .manual:
                TextField("Username", text: $model.username)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                Text("Credentials are stored securely using the macOS keychain.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            case .identity:
                if sortedIdentities.isEmpty {
                    Text("Create an identity to reuse credentials across connections.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Picker(
                        "Identity",
                        selection: Binding<UUID?>(
                            get: { model.identityID },
                            set: { model.identityID = $0 }
                        )
                    ) {
                        ForEach(sortedIdentities, id: \.id) { identity in
                            Text(identity.name).tag(UUID?.some(identity.id))
                        }
                    }
                    .pickerStyle(.menu)

                    if let identity = selectedIdentity {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Username: \(identity.username)")
                                .font(.subheadline)
                            Text("Passwords remain in the identity's keychain entry.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            case .inherit:
                if model.folderID == nil {
                    Text("Select a folder to inherit credentials from its hierarchy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let identity = inheritedIdentity {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Using identity \"\(identity.name)\" from selected folder")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Username: \(identity.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("The selected folder does not provide credentials yet.")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private func folderSummaryView(for folder: SavedFolder) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(folder.color)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(folderDisplayName(folder))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(folderCredentialDescription(folder))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func folderCredentialDescription(_ folder: SavedFolder) -> String {
        switch folder.credentialMode {
        case .none:
            return "No credentials configured"
        case .identity:
            if let identity = appModel.identities.first(where: { $0.id == folder.identityID }) {
                return "Uses identity \(identity.name)"
            } else {
                return "Identity unavailable"
            }
        case .inherit:
            if let inherited = appModel.folderIdentity(for: folder.id) {
                return "Inherits credentials (\(inherited.name))"
            } else {
                return "Inherits credentials"
            }
        }
    }

    private func securitySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use SSL/TLS", isOn: $model.useTLS)
                .toggleStyle(.switch)

            Text("Enable secure connections when supported by the server.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func handleSave(action: SaveAction) {
        cancelActiveTest()
        let passwordToPersist: String?
        if model.credentialSource == .manual {
            passwordToPersist = password.isEmpty ? nil : password
        } else {
            passwordToPersist = nil
        }
        onSave(model, passwordToPersist, action)
        dismiss()
    }

    private func handleTestButton() {
        if isTestingConnection {
            cancelActiveTest()
        } else {
            startConnectionTest()
        }
    }

    private func startConnectionTest() {
        cancelActiveTest()
        isTestingConnection = true
        testResult = nil

        let snapshot = model
        let overridePassword = model.credentialSource == .manual ? password : nil
        testTask = Task {
            await runConnectionTest(connection: snapshot, passwordOverride: overridePassword)
        }
    }

    private func cancelActiveTest() {
        testTask?.cancel()
        testTask = nil
        isTestingConnection = false
    }

    private func runConnectionTest(connection: SavedConnection, passwordOverride: String?) async {
        let result = await appModel.testConnection(connection, passwordOverride: passwordOverride)

        if Task.isCancelled { return }

        await MainActor.run {
            testResult = result
            isTestingConnection = false
            testTask = nil
        }
    }

    private func updateDatabaseType(_ newType: DatabaseType) {
        let previousType = model.databaseType
        let previousPort = model.port
        model.databaseType = newType

        guard previousType != newType else { return }

        if previousPort == previousType.defaultPort || previousPort <= 0 {
            model.port = newType.defaultPort
        }
    }

    private func folderDisplayName(_ folder: SavedFolder) -> String {
        var components: [String] = [folder.name]
        var current = folder
        var visited: Set<UUID> = [folder.id]

        while let parentID = current.parentFolderID,
              !visited.contains(parentID),
              let parent = appModel.folders.first(where: { $0.id == parentID }) {
            components.append(parent.name)
            current = parent
            visited.insert(parent.id)
        }

        return components.reversed().joined(separator: " / ")
    }
}

struct ConnectionTestResultView: View {
    let result: ConnectionTestResult

    var body: some View {
        GroupBox("Connection Test") {
            HStack(spacing: 12) {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(result.success ? .green : .red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.message)
                        .font(.headline)
                    if !result.details.isEmpty {
                        Text(result.details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

private struct PaletteColorSwatch: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: hex) ?? .accentColor)
                    .frame(width: 32, height: 32)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle((Color(hex: hex) ?? .accentColor).contrastingForegroundColor)
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.primary.opacity(0.6) : Color.primary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(hex)")
    }
}

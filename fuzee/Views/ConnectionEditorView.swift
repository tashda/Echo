import SwiftUI
#if os(macOS)
import AppKit
#endif

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

    @State private var selectedDatabaseType: DatabaseType
    @State private var connectionName: String
    @State private var host: String
    @State private var port: Int
    @State private var database: String
    @State private var username: String
    @State private var password: String
    @State private var credentialSource: CredentialSource
    @State private var identityID: UUID?
    @State private var folderID: UUID?
    @State private var useTLS: Bool
    @State private var colorHex: String

    @State private var isTestingConnection = false
    @State private var testResult: ConnectionTestResult?
    @State private var testTask: Task<Void, Never>?
    @State private var showingIdentityCreator = false
    @State private var showingTestAlert = false

    private let originalConnection: SavedConnection?
    let onSave: (SavedConnection, String?, SaveAction) -> Void

    init(connection: SavedConnection?, onSave: @escaping (SavedConnection, String?, SaveAction) -> Void) {
        self.originalConnection = connection
        self.onSave = onSave

        let model = connection ?? SavedConnection(
            id: UUID(),
            connectionName: "",
            host: "",
            port: DatabaseType.postgresql.defaultPort,
            database: "",
            username: "",
            credentialSource: .manual,
            identityID: nil,
            keychainIdentifier: nil,
            folderID: nil,
            useTLS: true,
            databaseType: .postgresql,
            serverVersion: nil,
            colorHex: ConnectionEditorView.colorPalette.first ?? "",
            cachedStructure: nil,
            cachedStructureUpdatedAt: nil
        )

        _selectedDatabaseType = State(initialValue: model.databaseType)
        _connectionName = State(initialValue: model.connectionName)
        _host = State(initialValue: model.host)
        _port = State(initialValue: model.port)
        _database = State(initialValue: model.database)
        _username = State(initialValue: model.username)
        _password = State(initialValue: "")
        _credentialSource = State(initialValue: model.credentialSource)
        _identityID = State(initialValue: model.identityID)
        _folderID = State(initialValue: model.folderID)
        _useTLS = State(initialValue: model.useTLS)
        _colorHex = State(initialValue: model.colorHex.isEmpty ? (ConnectionEditorView.colorPalette.first ?? "") : model.colorHex)
    }

    private var currentColor: Color {
        Color(hex: colorHex) ?? .accentColor
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
        guard let identityID = identityID else { return nil }
        return sortedIdentities.first { $0.id == identityID }
    }

    private var inheritedIdentity: SavedIdentity? {
        guard let folderID = folderID else { return nil }
        return appModel.folderIdentity(for: folderID)
    }

    private var isFormValid: Bool {
        let trimmedName = connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasValidPort = (1...65535).contains(port)

        let credentialsValid: Bool
        switch credentialSource {
        case .manual:
            credentialsValid = !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .identity:
            credentialsValid = identityID != nil
        case .inherit:
            credentialsValid = folderID != nil && inheritedIdentity != nil
        }

        if trimmedName.isEmpty || trimmedHost.isEmpty || !hasValidPort {
            return false
        }

        return credentialsValid
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 700, height: 550)
        .onDisappear { cancelActiveTest() }
        .sheet(isPresented: $showingIdentityCreator) {
            IdentityEditorView { identity, password in
                Task {
                    await appModel.upsertIdentity(identity, password: password)
                    identityID = identity.id
                }
            }
            .environmentObject(appModel)
        }
        .alert(testResult?.success == true ? "Connection Successful" : "Connection Failed", isPresented: $showingTestAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let result = testResult {
                if result.details.isEmpty {
                    Text(result.message)
                } else {
                    Text(result.details)
                }
            }
        }
    }

    // MARK: - Sidebar
    private var sidebarView: some View {
        List(selection: $selectedDatabaseType) {
            ForEach(DatabaseType.allCases, id: \.self) { type in
                Label {
                    Text(type.displayName)
                } icon: {
                    Image(type.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
                .tag(type)
            }
        }
        .navigationTitle("Database")
        .navigationSplitViewColumnWidth(min: 160, ideal: 160, max: 200)
        .onChange(of: selectedDatabaseType) { _, newType in
            let oldDefaults = DatabaseType.allCases.map { $0.defaultPort }
            if oldDefaults.contains(port) || port == 0 {
                port = newType.defaultPort
            }
        }
    }

    // MARK: - Detail View
    private var detailView: some View {
        VStack(spacing: 0) {
            ScrollView {
                Form {
                    Section {
                        LabeledContent("Name") {
                            TextField("", text: $connectionName, prompt: Text("My Connection"))
                                .multilineTextAlignment(.trailing)
                        }

                        LabeledContent("Color") {
                            HStack(spacing: 8) {
                                ForEach(Self.colorPalette, id: \.self) { hex in
                                    Button {
                                        colorHex = hex.uppercased()
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: hex) ?? .accentColor)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(
                                                        Color.primary.opacity(colorHex.uppercased() == hex.uppercased() ? 0.6 : 0.2),
                                                        lineWidth: colorHex.uppercased() == hex.uppercased() ? 2.5 : 1
                                                    )
                                            )
                                            .overlay(
                                                Group {
                                                    if colorHex.uppercased() == hex.uppercased() {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 11, weight: .bold))
                                                            .foregroundStyle(.white)
                                                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                                                    }
                                                }
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } header: {
                        Text("General")
                    }

                    Section {
                        Picker("Folder", selection: $folderID) {
                            Text("Root").tag(nil as UUID?)
                            ForEach(sortedFolders, id: \.id) { folder in
                                Text(folderDisplayName(folder)).tag(folder.id as UUID?)
                            }
                        }
                        .onChange(of: folderID) { _, newFolderID in
                            if newFolderID == nil && credentialSource == .inherit {
                                credentialSource = .manual
                            }
                        }
                    } header: {
                        Text("Organization")
                    }

                    Section {
                        LabeledContent("Host") {
                            TextField("", text: $host, prompt: Text("localhost"))
                                .multilineTextAlignment(.trailing)
                        }

                        LabeledContent("Port") {
                            TextField("", value: $port, format: .number.grouping(.never), prompt: Text("\(selectedDatabaseType.defaultPort)"))
                                .multilineTextAlignment(.trailing)
                        }

                        LabeledContent("Database") {
                            TextField("", text: $database, prompt: Text("postgres (optional)"))
                                .multilineTextAlignment(.trailing)
                                .disabled(selectedDatabaseType == .sqlite)
                        }
                    } header: {
                        Text("Server")
                    }

                    Section {
                        Picker("Method", selection: $credentialSource) {
                            Text("Manual").tag(CredentialSource.manual)
                            Text("Identity").tag(CredentialSource.identity)
                            if folderID != nil {
                                Text("Inherit").tag(CredentialSource.inherit)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: credentialSource) { _, newSource in
                            switch newSource {
                            case .manual:
                                break
                            case .identity:
                                password = ""
                                if identityID == nil || !appModel.identities.contains(where: { $0.id == identityID }) {
                                    identityID = appModel.identities.first?.id
                                }
                            case .inherit:
                                password = ""
                            }
                        }

                        switch credentialSource {
                        case .manual:
                            LabeledContent("Username") {
                                TextField("", text: $username, prompt: Text("username"))
                                    .multilineTextAlignment(.trailing)
                            }

                            LabeledContent("Password") {
                                SecureField("", text: $password, prompt: Text("password"))
                                    .multilineTextAlignment(.trailing)
                            }

                        case .identity:
                            if sortedIdentities.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("No identities available.")
                                        .foregroundStyle(.secondary)
                                        .font(.callout)
                                    Button("Create Identity") {
                                        showingIdentityCreator = true
                                    }
                                    .buttonStyle(.link)
                                }
                            } else {
                                Picker("Identity", selection: $identityID) {
                                    ForEach(sortedIdentities, id: \.id) { identity in
                                        Text(identity.name).tag(identity.id as UUID?)
                                    }
                                }
                                .pickerStyle(.menu)

                                HStack {
                                    Button("Create Identity") {
                                        showingIdentityCreator = true
                                    }
                                    .buttonStyle(.link)
                                    Spacer()
                                }
                            }

                        case .inherit:
                            if let identity = inheritedIdentity {
                                Text("This connection will use the identity '\(identity.name)' inherited from the selected folder.")
                                    .foregroundStyle(.secondary)
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("The selected folder does not have credentials configured.")
                                    .foregroundStyle(.red)
                                    .font(.callout)
                            }
                        }
                    } header: {
                        Text("Authentication")
                    }

                    Section {
                        Toggle("Use SSL/TLS", isOn: $useTLS)
                    } header: {
                        Text("Security")
                    } footer: {
                        Text("Enable encrypted connections when supported by the server.")
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }

            Divider()

            toolbarView
        }
    }

    // MARK: - Toolbar
    private var toolbarView: some View {
        HStack(spacing: 12) {
            Button(action: handleTestButton) {
                HStack(spacing: 6) {
                    if isTestingConnection {
                        ProgressView().controlSize(.small)
                        Text("Cancel Test")
                    } else {
                        Image(systemName: "link.badge.plus")
                        Text("Test Connection")
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(!isTestingConnection && !isFormValid)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                handleSave(action: .save)
            }
            .disabled(!isFormValid)

            Button("Save & Connect") {
                handleSave(action: .saveAndConnect)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions
    private func handleSave(action: SaveAction) {
        cancelActiveTest()

        let generatedLogo = generateConnectionLogo(
            databaseType: selectedDatabaseType,
            color: currentColor
        )

        let connection = SavedConnection(
            id: originalConnection?.id ?? UUID(),
            connectionName: connectionName.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            database: database.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            credentialSource: credentialSource,
            identityID: identityID,
            keychainIdentifier: originalConnection?.keychainIdentifier,
            folderID: folderID,
            useTLS: useTLS,
            databaseType: selectedDatabaseType,
            serverVersion: originalConnection?.serverVersion,
            colorHex: colorHex,
            logo: generatedLogo,
            cachedStructure: originalConnection?.cachedStructure,
            cachedStructureUpdatedAt: originalConnection?.cachedStructureUpdatedAt
        )

        let passwordToPersist = credentialSource == .manual && !password.isEmpty ? password : nil
        onSave(connection, passwordToPersist, action)
        dismiss()
    }

    private func generateConnectionLogo(databaseType: DatabaseType, color: Color) -> Data? {
        let size: CGFloat = 64
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()
        defer { image.unlockFocus() }

        // Draw background with color
        let backgroundColor = NSColor(color.opacity(0.15))
        backgroundColor.setFill()
        let backgroundPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 12, yRadius: 12)
        backgroundPath.fill()

        // Draw database icon
        if let iconImage = NSImage(systemSymbolName: databaseType.iconName, accessibilityDescription: nil) {
            let iconSize: CGFloat = 32
            let iconRect = NSRect(
                x: (size - iconSize) / 2,
                y: (size - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )

            iconImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)

            // Tint the icon with the color
            NSColor(color).setFill()
            iconRect.fill(using: .sourceAtop)
        }

        // Convert to PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData
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

        let connection = SavedConnection(
            id: originalConnection?.id ?? UUID(),
            connectionName: connectionName,
            host: host,
            port: port,
            database: database,
            username: username,
            credentialSource: credentialSource,
            identityID: identityID,
            keychainIdentifier: originalConnection?.keychainIdentifier,
            folderID: folderID,
            useTLS: useTLS,
            databaseType: selectedDatabaseType,
            serverVersion: nil,
            colorHex: colorHex,
            cachedStructure: nil,
            cachedStructureUpdatedAt: nil
        )

        let overridePassword = credentialSource == .manual ? password : nil
        testTask = Task {
            await runConnectionTest(connection: connection, passwordOverride: overridePassword)
        }
    }

    private func cancelActiveTest() {
        testTask?.cancel()
        testTask = nil
        isTestingConnection = false
    }

    private func runConnectionTest(connection: SavedConnection, passwordOverride: String?) async {
        // Run the actual test with timeout
        do {
            let result = try await withThrowingTaskGroup(of: ConnectionTestResult.self) { group in
                // Add connection test task
                group.addTask {
                    await appModel.testConnection(connection, passwordOverride: passwordOverride)
                }

                // Add timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    return await ConnectionTestResult(
                        isSuccessful: false,
                        message: "Connection timed out",
                        responseTime: 10.0,
                        serverVersion: nil
                    )
                }

                // Return the first result
                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            guard !Task.isCancelled else {
                await MainActor.run {
                    testResult = ConnectionTestResult(
                        isSuccessful: false,
                        message: "Connection test cancelled",
                        responseTime: nil,
                        serverVersion: nil
                    )
                    isTestingConnection = false
                    self.testTask = nil
                    showingTestAlert = true
                }
                return
            }

            await MainActor.run {
                testResult = result
                isTestingConnection = false
                self.testTask = nil
                showingTestAlert = true
            }
        } catch {
            // Handle cancellation
            await MainActor.run {
                testResult = ConnectionTestResult(
                    isSuccessful: false,
                    message: "Connection test cancelled",
                    responseTime: nil,
                    serverVersion: nil
                )
                isTestingConnection = false
                self.testTask = nil
                showingTestAlert = true
            }
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


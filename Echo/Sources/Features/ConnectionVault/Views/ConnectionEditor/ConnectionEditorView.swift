import SwiftUI

struct TestLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let kind: Kind

    enum Kind {
        case info
        case success
        case error
    }
}

struct ConnectionEditorView: View {
    enum SaveAction {
        case save
        case saveAndConnect
        case connect
    }

    static let colorPalette: [String] = [
        "5A9CDE", "6EAE72", "E8943A", "9B72CF", "D4687A"
    ]

    @Environment(\.dismiss) internal var dismiss
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore

    @EnvironmentObject internal var environmentState: EnvironmentState

    @State internal var selectedDatabaseType: DatabaseType
    @State internal var connectionName: String
    @State internal var host: String
    @State internal var port: Int
    @State internal var database: String
    @State internal var username: String
    @State internal var domain: String
    @State internal var password: String
    @State internal var authenticationMethod: DatabaseAuthenticationMethod
    @State internal var credentialSource: CredentialSource
    @State internal var identityID: UUID?
    @State internal var folderID: UUID?
    @State internal var useTLS: Bool
    @State internal var trustServerCertificate: Bool
    @State internal var tlsMode: TLSMode
    @State internal var sslRootCertPath: String?
    @State internal var sslCertPath: String?
    @State internal var sslKeyPath: String?
    @State internal var mssqlEncryptionMode: MSSQLEncryptionMode
    @State internal var colorHex: String

    @State internal var passwordDirty = false
    @State internal var hasSavedPassword = false
    @State internal var isTestingConnection = false
    @State internal var testResult: ConnectionTestResult?
    @State internal var testTask: Task<Void, Never>?
    @State internal var testLogEntries: [TestLogEntry] = []
    @State internal var identityEditorState: IdentityEditorState?

    internal let originalConnection: SavedConnection?
    internal let isQuickConnect: Bool
    let onSave: (SavedConnection, String?, SaveAction) -> Void

    init(connection: SavedConnection?, isQuickConnect: Bool = false, onSave: @escaping (SavedConnection, String?, SaveAction) -> Void) {
        self.originalConnection = connection
        self.isQuickConnect = isQuickConnect
        self.onSave = onSave

        let model = connection ?? SavedConnection(
            id: UUID(),
            connectionName: "",
            host: "",
            port: DatabaseType.postgresql.defaultPort,
            database: "",
            username: "",
            authenticationMethod: .sqlPassword,
            domain: "",
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
        _domain = State(initialValue: model.domain)
        _password = State(initialValue: "")
        _authenticationMethod = State(initialValue: model.authenticationMethod)
        _credentialSource = State(initialValue: model.credentialSource)
        _identityID = State(initialValue: model.identityID)
        _folderID = State(initialValue: model.folderID)
        _useTLS = State(initialValue: model.useTLS)
        _trustServerCertificate = State(initialValue: model.trustServerCertificate)
        _tlsMode = State(initialValue: model.tlsMode)
        _sslRootCertPath = State(initialValue: model.sslRootCertPath)
        _sslCertPath = State(initialValue: model.sslCertPath)
        _sslKeyPath = State(initialValue: model.sslKeyPath)
        _mssqlEncryptionMode = State(initialValue: model.mssqlEncryptionMode)
        _colorHex = State(initialValue: model.colorHex.isEmpty ? (ConnectionEditorView.colorPalette.first ?? "") : model.colorHex)
    }

    internal var currentColor: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    internal var sortedFolders: [SavedFolder] {
        connectionStore.folders
            .filter { $0.kind == .connections }
            .sorted { lhs, rhs in
                folderDisplayName(lhs).localizedCaseInsensitiveCompare(folderDisplayName(rhs)) == .orderedAscending
            }
    }

    internal var sortedIdentities: [SavedIdentity] {
        connectionStore.identities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    internal var availableAuthenticationMethods: [DatabaseAuthenticationMethod] {
        selectedDatabaseType.supportedAuthenticationMethods
    }

    internal var availableCredentialSources: [CredentialSource] {
        var sources: [CredentialSource] = [.manual]
        if authenticationMethod.supportsExternalCredentials {
            sources.append(.identity)
            if folderID != nil {
                sources.append(.inherit)
            }
        }
        return sources
    }

    internal var inheritedIdentity: SavedIdentity? {
        guard let folderID = folderID else { return nil }
        return environmentState.identityRepository.resolveInheritedIdentity(folderID: folderID)
    }

    internal var isFormValid: Bool {
        let trimmedName = connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        if selectedDatabaseType == .sqlite {
            return !trimmedName.isEmpty && !trimmedHost.isEmpty
        }

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

        if authenticationMethod == .windowsIntegrated {
            guard credentialSource == .manual else { return false }
            let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedDomain.isEmpty, !trimmedUsername.isEmpty, !trimmedPassword.isEmpty else { return false }
        }

        if authenticationMethod == .accessToken {
            let trimmedToken = password.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedToken.isEmpty || (hasSavedPassword && !passwordDirty) else { return false }
        }

        return credentialsValid
    }

    var body: some View {
        VStack(spacing: 0) {
            detailView
        }
        .frame(width: 520)
        .frame(minHeight: 400, idealHeight: 580, maxHeight: 720)
        .onAppear {
            if originalConnection == nil && folderID == nil {
                folderID = connectionStore.selectedFolderID
            }
            if let conn = originalConnection, conn.credentialSource == .manual {
                hasSavedPassword = environmentState.identityRepository.password(for: conn) != nil
            }
        }
        .onDisappear { cancelActiveTest() }
        .sheet(item: $identityEditorState) { state in
            IdentityEditorSheet(state: state, onSave: { newIdentity in
                identityID = newIdentity.id
            })
            .environmentObject(environmentState)
        }
        .onChange(of: selectedDatabaseType) { oldType, newType in
            handleDatabaseTypeChange(from: oldType, to: newType)
        }
        .onChange(of: authenticationMethod) { _, newMethod in
            if newMethod == .windowsIntegrated {
                credentialSource = .manual
            }
        }
    }

    internal func handleDatabaseTypeChange(from oldType: DatabaseType, to newType: DatabaseType) {
        if newType == .sqlite {
            port = 0
            useTLS = false
            credentialSource = .manual
            identityID = nil
            username = ""
            password = ""
            database = ""
            authenticationMethod = .sqlPassword
            domain = ""
        } else {
            if oldType == .sqlite || port == 0 || port == oldType.defaultPort {
                port = newType.defaultPort
            }
            let supportedMethods = newType.supportedAuthenticationMethods
            if !supportedMethods.contains(authenticationMethod) {
                authenticationMethod = newType.defaultAuthenticationMethod
            }
            if authenticationMethod == .windowsIntegrated {
                credentialSource = .manual
            }
        }
    }
}

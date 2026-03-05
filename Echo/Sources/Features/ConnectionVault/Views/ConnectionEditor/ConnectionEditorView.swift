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
    @State internal var colorHex: String

    @State internal var isTestingConnection = false
    @State internal var testResult: ConnectionTestResult?
    @State internal var testTask: Task<Void, Never>?
    @State internal var identityEditorState: IdentityEditorState?
    @State internal var showingTestAlert = false

    internal let originalConnection: SavedConnection?
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
        .onAppear {
            if originalConnection == nil && folderID == nil {
                folderID = connectionStore.selectedFolderID
            }
        }
        .onDisappear { cancelActiveTest() }
        .sheet(item: $identityEditorState) { state in
            IdentityEditorSheet(state: state, onSave: { newIdentity in
                identityID = newIdentity.id
            })
            .environmentObject(environmentState)
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
        .background(Color.clear)
    }
}

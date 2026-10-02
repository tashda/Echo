import SwiftUI

struct ConnectionEditorView: View {
    enum SaveAction {
        case save
        case saveAndConnect
        case connect
    }

    /// A sheet (Quick Connect, New Connection) or the detail pane of Manage Connections.
    enum Presentation {
        case sheet
        case inline
    }

    /// Round MC: a new connection starts by choosing its engine; the form follows. A saved
    /// connection opens on the form, and its engine never changes.
    enum Step {
        case chooseEngine
        case form
    }

    enum EditorField: Hashable {
        case host, port, username, domain, password, name, keyPassword
        /// An extra PostgreSQL server row (round 23, FH1), by position.
        case additionalHost(Int)
    }

    /// The thirty server colours (round 50, PC3), as the hex a connection saves.
    static let colorPalette: [String] = ServerColorPalette.all.map(\.lightHex)

    @Environment(\.dismiss) internal var dismiss
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore

    @Environment(EnvironmentState.self) internal var environmentState
    @Environment(\.echoMotion) internal var motion

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
    @State internal var useTLS: Bool
    @State internal var trustServerCertificate: Bool
    @State internal var tlsMode: TLSMode
    @State internal var sslRootCertPath: String?
    @State internal var sslCertPath: String?
    @State internal var sslKeyPath: String?
    @State internal var mssqlEncryptionMode: MSSQLEncryptionMode
    @State internal var hostNameInCertificate: String
    @State internal var readOnlyIntent: Bool
    @State internal var allowLegacyTLS: Bool
    @State internal var connectionTimeout: TimeInterval
    /// The query time limit override in seconds (round 21, TW2): empty uses the Settings default.
    @State internal var queryTimeLimit: TimeInterval?
    @State internal var confirmUnguardedWrites: Bool?
    @State internal var keepsQueryHistory = true
    @State internal var colorHex: String
    /// The symbol or emoji chosen for the server (round 51, CU2).
    @State internal var railGlyph: ServerRailGlyph?
    /// Round 23: several PostgreSQL servers (FH1), which to use (FT1), and load balancing from a
    /// pasted URL (FL1).
    @State internal var additionalHosts: [ConnectionHost]
    @State internal var targetSessionAttributes: PostgresConnectTo
    @State internal var loadBalanceHosts: Bool
    /// Round 23, Kerberos: the service name (KS1; empty means postgres) and the ticket line (KT1).
    @State internal var kerberosServiceName: String
    @State internal var kerberosTicket: KerberosTicketStatus?
    /// Round 23, client key: the key password (KW1, KK1).
    @State internal var keyPassword = ""
    @State internal var keyPasswordDirty = false
    @State internal var hasSavedKeyPassword = false
    /// Whether the chosen key or .p12 file is protected by a password (read from the file).
    @State internal var keyNeedsPassword = false

    @State internal var passwordDirty = false
    @State internal var hasSavedPassword = false
    @State internal var isTestingConnection = false
    @State internal var testResult: ConnectionTestResult?
    @State internal var testTask: Task<Void, Never>?
    @State internal var testLogEntries: [TestLogEntry] = []
    @State internal var identityEditorState: IdentityEditorState?
    @State internal var saveToConnections: Bool
    @State internal var showsValidation = false
    @State internal var isShowingTestLog = false
    /// Round MC: the engine step, the pasted or built connection string, and its selection.
    @State internal var step: Step
    @State internal var connectionString = ""
    @State internal var connectionStringSelection: TextSelection?
    @State internal var connectionStringIssue: String?
    /// The example's parts Tab still has to visit (user, host, port, database).
    @State internal var connectionStringParts: [String] = []
    @State internal var hoveredEngine: DatabaseType?
    @State internal var isShowingAppearance = false
    @AppStorage("connectionEditor.lastEngine") internal var lastEngineRawValue = DatabaseType.postgresql.rawValue
    @FocusState internal var focusedField: EditorField?
    @AppStorage("connectionEditor.optionsExpanded") internal var optionsExpanded = false

    internal let originalConnection: SavedConnection?
    internal let isQuickConnect: Bool
    internal let presentation: Presentation
    internal let onRevert: (() -> Void)?
    /// What the ✓ button does in a sheet: save and connect from the main window, save only from
    /// Manage Connections. An inline editor always saves.
    internal let confirmAction: SaveAction
    /// Told when the form gains or loses unsaved changes (Manage Connections asks before leaving).
    internal let onChangesChanged: ((Bool) -> Void)?
    /// Told what stops a save (a missing field, in words), or nil when the form can be saved, so
    /// Manage Connections offers Save in its leave alert only when a save can work.
    internal let onSaveBlockerChanged: ((String?) -> Void)?
    /// Changing this asks the editor to save (Manage Connections' "Save" in its leave alert).
    internal let saveRequest: Int
    let onSave: (SavedConnection, String?, SaveAction) -> Void
    /// The values the form started from, to tell whether anything changed.
    internal let initialSnapshot: ConnectionEditorSnapshot

    init(connection: SavedConnection?, isQuickConnect: Bool = false, presentation: Presentation = .sheet,
         confirmAction: SaveAction = .saveAndConnect, saveRequest: Int = 0,
         onChangesChanged: ((Bool) -> Void)? = nil,
         onSaveBlockerChanged: ((String?) -> Void)? = nil,
         onRevert: (() -> Void)? = nil, onSave: @escaping (SavedConnection, String?, SaveAction) -> Void) {
        self.originalConnection = connection
        self.isQuickConnect = isQuickConnect
        self.presentation = presentation
        self.confirmAction = confirmAction
        self.saveRequest = saveRequest
        self.onChangesChanged = onChangesChanged
        self.onSaveBlockerChanged = onSaveBlockerChanged
        self.onRevert = onRevert
        self.onSave = onSave
        _saveToConnections = State(initialValue: !isQuickConnect)
        _step = State(initialValue: connection == nil ? .chooseEngine : .form)

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
            useTLS: true,
            databaseType: .postgresql,
            serverVersion: nil,
            colorHex: ServerColorPalette.defaultColor.lightHex,
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
        _useTLS = State(initialValue: model.useTLS)
        _trustServerCertificate = State(initialValue: model.trustServerCertificate)
        _tlsMode = State(initialValue: model.tlsMode)
        _sslRootCertPath = State(initialValue: model.sslRootCertPath)
        _sslCertPath = State(initialValue: model.sslCertPath)
        _sslKeyPath = State(initialValue: model.sslKeyPath)
        _mssqlEncryptionMode = State(initialValue: model.mssqlEncryptionMode)
        _hostNameInCertificate = State(initialValue: model.hostNameInCertificate ?? "")
        _readOnlyIntent = State(initialValue: model.readOnlyIntent)
        _allowLegacyTLS = State(initialValue: model.allowLegacyTLS)
        _connectionTimeout = State(initialValue: model.connectionTimeout)
        _queryTimeLimit = State(initialValue: model.queryTimeLimit)
        _confirmUnguardedWrites = State(initialValue: model.confirmUnguardedWrites)
        _keepsQueryHistory = State(initialValue: model.keepsQueryHistory)
        _additionalHosts = State(initialValue: model.additionalHosts)
        _targetSessionAttributes = State(initialValue: model.targetSessionAttributes)
        _loadBalanceHosts = State(initialValue: model.loadBalanceHosts)
        _kerberosServiceName = State(initialValue: model.kerberosServiceName ?? "")
        _colorHex = State(initialValue: model.colorHex.isEmpty ? ServerColorPalette.defaultColor.lightHex : model.colorHex)
        _railGlyph = State(initialValue: model.railGlyph)
        initialSnapshot = ConnectionEditorSnapshot(model: model)
    }

    internal var currentColor: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    internal var sortedIdentities: [SavedIdentity] {
        connectionStore.identities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    internal var availableAuthenticationMethods: [DatabaseAuthenticationMethod] {
        selectedDatabaseType.supportedAuthenticationMethods
    }

    /// The engine a new connection starts from: the one chosen last.
    internal var lastEngine: DatabaseType {
        DatabaseType(rawValue: lastEngineRawValue) ?? .postgresql
    }

    var body: some View {
        Group {
            if presentation == .sheet {
                detailView
                    .frame(width: ConnectionEditorMetrics.sheetWidth)
                    .frame(minHeight: 360, idealHeight: 560, maxHeight: 720)
            } else {
                detailView
            }
        }
        .onAppear {
            if let conn = originalConnection, conn.credentialSource == .manual {
                hasSavedPassword = environmentState.identityRepository.password(for: conn) != nil
            }
            if let conn = originalConnection, conn.sslCertPath != nil {
                hasSavedKeyPassword = ConnectionKeyPasswordStore.password(for: conn.id) != nil
            }
            if authenticationMethod == .kerberos { refreshKerberosTicket() }
        }
        .onDisappear { cancelActiveTest() }
        .onChange(of: hasChanges) { _, changed in onChangesChanged?(changed) }
        .onChange(of: missingForTest, initial: true) { _, missing in onSaveBlockerChanged?(missing) }
        .onChange(of: saveRequest) { _, _ in submit(.save) }
        // A result is only true for what was tested: any edit clears it and stops a running test.
        .onChange(of: currentSnapshot) { _, _ in
            if isTestingConnection { cancelActiveTest() }
            testResult = nil
            isShowingTestLog = false
        }
        .sheet(item: $identityEditorState) { state in
            IdentityEditorSheet(state: state, onSave: { newIdentity in
                identityID = newIdentity.id
                credentialSource = .identity
            })
            .environment(environmentState)
            .environment(projectStore)
            .environment(connectionStore)
        }
        .onChange(of: selectedDatabaseType) { oldType, newType in
            handleDatabaseTypeChange(from: oldType, to: newType)
        }
        .onChange(of: host) { _, newValue in applyPastedConnectionString(newValue) }
        .onChange(of: authenticationMethod) { _, newMethod in
            if newMethod == .windowsIntegrated {
                credentialSource = .manual
            }
            if newMethod == .kerberos { kerberosMethodChosen() }
        }
    }
}

enum ConnectionEditorMetrics {
    /// Round MC: the compact sheet (B).
    static let sheetWidth: CGFloat = 460
}

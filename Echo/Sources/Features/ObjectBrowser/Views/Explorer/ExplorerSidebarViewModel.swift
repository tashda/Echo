import SwiftUI
import Combine
import EchoSense

@MainActor
final class ObjectBrowserSidebarViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedSearchText = ""
    @Published var isSearchFieldFocused = false
    @Published var expandedServerIDs: Set<UUID> = []
    @Published var selectedObjectID: String?
    @Published var knownSessionIDs: Set<UUID> = []

    /// Maps connection ID → session ID for the last initialized session.
    /// Used to detect reconnects (same connection ID, new session ID).
    internal var lastInitializedSessionID: [UUID: UUID] = [:]

    // Per-session state
    @Published var expandedDatabasesBySession: [UUID: Set<String>] = [:]
    @Published var expandedObjectGroupsBySession: [String: Set<SchemaObjectInfo.ObjectType>] = [:]
    @Published var expandedObjectIDsBySession: [String: Set<String>] = [:]
    @Published var selectedSchemaNameBySession: [String: String] = [:]
    /// Stores the auto-expand object types per connection, derived from sidebar settings at init time.
    internal var defaultExpandedObjectTypes: [UUID: Set<SchemaObjectInfo.ObjectType>] = [:]
    @Published var pinnedObjectIDsByDatabase: [String: Set<String>] = [:]
    @Published var pinnedSectionExpandedByDatabase: [String: Bool] = [:]
    @Published var databaseSchemaLoadingStates: [String: Bool] = [:]
    /// Tracks databases whose schema has been fetched at least once (prevents re-fetch loops when the database has no user objects).
    @Published var databaseSchemaLoadedOnce: Set<String> = []

    // Server folder groups (Databases, Management, etc.)
    @Published var databasesFolderExpandedBySession: [UUID: Bool] = [:]
    @Published var managementFolderExpandedBySession: [UUID: Bool] = [:]

    // Agent Jobs state (per-connection, MSSQL only)
    @Published var agentJobsExpandedBySession: [UUID: Bool] = [:]
    @Published var agentJobsBySession: [UUID: [AgentJobItem]] = [:]
    @Published var agentJobsLoadingBySession: [UUID: Bool] = [:]
    @Published var showNewJobSheet = false
    @Published var newJobSessionID: UUID?

    // Security state — server-level (per-connection)
    @Published var securityFolderExpandedBySession: [UUID: Bool] = [:]
    @Published var securityLoginsExpandedBySession: [UUID: Bool] = [:]
    @Published var securityServerRolesExpandedBySession: [UUID: Bool] = [:]
    @Published var securityCredentialsExpandedBySession: [UUID: Bool] = [:]
    @Published var securityCertLoginsExpandedBySession: [UUID: Bool] = [:]
    @Published var securityLoginsBySession: [UUID: [SecurityLoginItem]] = [:]
    @Published var securityServerRolesBySession: [UUID: [SecurityServerRoleItem]] = [:]
    @Published var securityCredentialsBySession: [UUID: [SecurityCredentialItem]] = [:]
    @Published var securityServerLoadingBySession: [UUID: Bool] = [:]
    // PG separate folders
    @Published var securityPGLoginRolesExpandedBySession: [UUID: Bool] = [:]
    @Published var securityPGGroupRolesExpandedBySession: [UUID: Bool] = [:]
    // MSSQL server role sheet
    @Published var showSecurityServerRoleSheet = false
    @Published var securityServerRoleSheetSessionID: UUID?

    // Security state — database-level (keyed by "connID#dbName")
    @Published var dbSecurityExpandedByDB: [String: Bool] = [:]
    @Published var dbSecurityUsersExpandedByDB: [String: Bool] = [:]
    @Published var dbSecurityRolesExpandedByDB: [String: Bool] = [:]
    @Published var dbSecurityAppRolesExpandedByDB: [String: Bool] = [:]
    @Published var dbSecuritySchemasExpandedByDB: [String: Bool] = [:]
    @Published var dbSecurityUsersByDB: [String: [SecurityUserItem]] = [:]
    @Published var dbSecurityRolesByDB: [String: [SecurityDatabaseRoleItem]] = [:]
    @Published var dbSecurityAppRolesByDB: [String: [SecurityAppRoleItem]] = [:]
    @Published var dbSecuritySchemasByDB: [String: [SecuritySchemaItem]] = [:]
    @Published var dbSecurityLoadingByDB: [String: Bool] = [:]

    // Security sheets
    @Published var showSecurityLoginSheet = false
    @Published var securityLoginSheetEditName: String?
    @Published var securityLoginSheetSessionID: UUID?
    @Published var showSecurityUserSheet = false
    @Published var securityUserSheetEditName: String?
    @Published var securityUserSheetSessionID: UUID?
    @Published var securityUserSheetDatabaseName: String?
    @Published var showSecurityPGRoleSheet = false
    @Published var securityPGRoleSheetEditName: String?
    @Published var securityPGRoleSheetSessionID: UUID?

    // Database properties sheet
    @Published var showDatabaseProperties = false
    @Published var propertiesDatabaseName: String?
    @Published var propertiesConnectionID: UUID?

    // Drop database confirmation
    @Published var showDropDatabaseAlert = false
    @Published var dropDatabaseTarget: DropDatabaseTarget?

    struct DropDatabaseTarget {
        let sessionID: UUID
        let connectionID: UUID
        let databaseName: String
        let databaseType: DatabaseType
        let variant: DropVariant
    }

    enum DropVariant {
        case standard
        case cascade
        case force
    }

    // Drop security principal confirmation
    @Published var showDropSecurityPrincipalAlert = false
    @Published var dropSecurityPrincipalTarget: DropSecurityPrincipalTarget?

    struct DropSecurityPrincipalTarget {
        let sessionID: UUID
        let connectionID: UUID
        let name: String
        let kind: SecurityPrincipalKind
        /// Database name, only for database-scoped principals (e.g. MSSQL users).
        let databaseName: String?
    }

    enum SecurityPrincipalKind: String {
        case pgRole = "Role"
        case mssqlLogin = "Login"
        case mssqlUser = "User"
        case mssqlServerRole = "Server Role"
    }

    struct AgentJobItem: Identifiable, Hashable {
        let id: String
        let name: String
        let enabled: Bool
        let lastOutcome: String?
    }

    struct SecurityLoginItem: Identifiable, Hashable {
        let id: String
        let name: String
        let loginType: String
        let isDisabled: Bool
    }

    struct SecurityServerRoleItem: Identifiable, Hashable {
        let id: String
        let name: String
        let isFixed: Bool
    }

    struct SecurityCredentialItem: Identifiable, Hashable {
        let id: String
        let name: String
        let identity: String
    }

    struct SecurityUserItem: Identifiable, Hashable {
        let id: String
        let name: String
        let userType: String
        let defaultSchema: String?
    }

    struct SecurityDatabaseRoleItem: Identifiable, Hashable {
        let id: String
        let name: String
        let isFixed: Bool
        let owner: String?
    }

    struct SecurityAppRoleItem: Identifiable, Hashable {
        let id: String
        let name: String
        let defaultSchema: String?
    }

    struct SecuritySchemaItem: Identifiable, Hashable {
        let id: String
        let name: String
        let owner: String?
    }

    private var searchDebounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    /// Tracks whether a debounce observer is already running.
    private var isDebounceActive = false

    func setupSearchDebounce(proxy: ScrollViewProxy) {
        guard !isDebounceActive else { return }
        isDebounceActive = true

        // Immediate path: clear debounced text instantly when search is cleared.
        // Debounced path: wait 200ms after last keystroke before applying.
        $searchText
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                self.searchDebounceTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.isEmpty {
                    self.debouncedSearchText = ""
                    self.searchDebounceTask = Task { @MainActor in
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                    }
                } else {
                    let pending = newValue
                    self.searchDebounceTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        guard !Task.isCancelled else { return }
                        self.debouncedSearchText = pending
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                    }
                }
            }
            .store(in: &cancellables)
    }

    func stopSearchDebounce() {
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        cancellables.removeAll()
        isDebounceActive = false
    }

    func resetFilters(for session: ConnectionSession?, selectedSession: ConnectionSession?) {
        if !searchText.isEmpty {
            searchText = ""
            debouncedSearchText = ""
        }
        guard let targetSession = session ?? selectedSession else { return }
        let connID = targetSession.connection.id
        let prefix = connID.uuidString + "#"
        for key in selectedSchemaNameBySession.keys where key.hasPrefix(prefix) { selectedSchemaNameBySession.removeValue(forKey: key) }
        for key in expandedObjectIDsBySession.keys where key.hasPrefix(prefix) { expandedObjectIDsBySession.removeValue(forKey: key) }
        let defaults = defaultExpandedObjectTypes[connID] ?? Set(SchemaObjectInfo.ObjectType.allCases)
        for key in expandedObjectGroupsBySession.keys where key.hasPrefix(prefix) { expandedObjectGroupsBySession[key] = defaults }
    }

    private func supportedObjectTypes(for session: ConnectionSession?) -> [SchemaObjectInfo.ObjectType] {
        guard let session else { return SchemaObjectInfo.ObjectType.allCases }
        return SchemaObjectInfo.ObjectType.supported(for: session.connection.databaseType)
    }

    // MARK: - Database Expansion

    func isDatabaseExpanded(connectionID: UUID, databaseName: String) -> Bool {
        expandedDatabasesBySession[connectionID]?.contains(databaseName) ?? false
    }

    func toggleDatabaseExpanded(connectionID: UUID, databaseName: String) {
        var expanded = expandedDatabasesBySession[connectionID] ?? []
        if expanded.contains(databaseName) {
            expanded.remove(databaseName)
        } else {
            expanded.insert(databaseName)
        }
        expandedDatabasesBySession[connectionID] = expanded
    }

    func isDatabaseLoading(connectionID: UUID, databaseName: String) -> Bool {
        databaseSchemaLoadingStates[pinnedStorageKey(connectionID: connectionID, databaseName: databaseName)] ?? false
    }

    func setDatabaseLoading(connectionID: UUID, databaseName: String, loading: Bool) {
        let key = pinnedStorageKey(connectionID: connectionID, databaseName: databaseName)
        databaseSchemaLoadingStates[key] = loading
        if !loading {
            databaseSchemaLoadedOnce.insert(key)
        }
    }

    func isDatabaseSchemaLoadedOnce(connectionID: UUID, databaseName: String) -> Bool {
        databaseSchemaLoadedOnce.contains(pinnedStorageKey(connectionID: connectionID, databaseName: databaseName))
    }

}

import SwiftUI
import EchoSense

@MainActor @Observable
final class ObjectBrowserSidebarViewModel {
    var searchText = ""
    var debouncedSearchText = ""
    var isSearchFieldFocused = false
    var expandedServerIDs: Set<UUID> = []
    var selectedObjectID: String?
    var knownSessionIDs: Set<UUID> = []

    /// Maps connection ID → session ID for the last initialized session.
    /// Used to detect reconnects (same connection ID, new session ID).
    @ObservationIgnored internal var lastInitializedSessionID: [UUID: UUID] = [:]

    // Per-session state
    var expandedDatabasesBySession: [UUID: Set<String>] = [:]
    var expandedObjectGroupsBySession: [String: Set<SchemaObjectInfo.ObjectType>] = [:]
    var expandedObjectIDsBySession: [String: Set<String>] = [:]
    var selectedSchemaNameBySession: [String: String] = [:]
    /// Stores the auto-expand object types per connection, derived from sidebar settings at init time.
    @ObservationIgnored internal var defaultExpandedObjectTypes: [UUID: Set<SchemaObjectInfo.ObjectType>] = [:]
    var pinnedObjectIDsByDatabase: [String: Set<String>] = [:]
    var pinnedSectionExpandedByDatabase: [String: Bool] = [:]
    var databaseSchemaLoadingStates: [String: Bool] = [:]
    /// Tracks databases whose schema has been fetched at least once (prevents re-fetch loops when the database has no user objects).
    var databaseSchemaLoadedOnce: Set<String> = []

    // Server folder groups (Databases, Management, etc.)
    var databasesFolderExpandedBySession: [UUID: Bool] = [:]
    var managementFolderExpandedBySession: [UUID: Bool] = [:]

    // Agent Jobs state (per-connection, MSSQL only)
    var agentJobsExpandedBySession: [UUID: Bool] = [:]
    var agentJobsBySession: [UUID: [AgentJobItem]] = [:]
    var agentJobsLoadingBySession: [UUID: Bool] = [:]
    var showNewJobSheet = false
    var newJobSessionID: UUID?

    // Linked Servers state (per-connection, MSSQL only)
    var linkedServersExpandedBySession: [UUID: Bool] = [:]
    var linkedServersBySession: [UUID: [LinkedServerItem]] = [:]
    var linkedServersLoadingBySession: [UUID: Bool] = [:]
    var showNewLinkedServerSheet = false
    var newLinkedServerSessionID: UUID?
    var showDropLinkedServerAlert = false
    var dropLinkedServerTarget: DropLinkedServerTarget?

    struct DropLinkedServerTarget {
        let connectionID: UUID
        let serverName: String
    }

    // Security state — server-level (per-connection)
    var securityFolderExpandedBySession: [UUID: Bool] = [:]
    var securityLoginsExpandedBySession: [UUID: Bool] = [:]
    var securityServerRolesExpandedBySession: [UUID: Bool] = [:]
    var securityCredentialsExpandedBySession: [UUID: Bool] = [:]
    var securityCertLoginsExpandedBySession: [UUID: Bool] = [:]
    var securityLoginsBySession: [UUID: [SecurityLoginItem]] = [:]
    var securityServerRolesBySession: [UUID: [SecurityServerRoleItem]] = [:]
    var securityCredentialsBySession: [UUID: [SecurityCredentialItem]] = [:]
    var securityServerLoadingBySession: [UUID: Bool] = [:]
    // PG separate folders
    var securityPGLoginRolesExpandedBySession: [UUID: Bool] = [:]
    var securityPGGroupRolesExpandedBySession: [UUID: Bool] = [:]
    // MSSQL server role sheet
    var showSecurityServerRoleSheet = false
    var securityServerRoleSheetSessionID: UUID?

    // Security state — database-level (keyed by "connID#dbName")
    var dbSecurityExpandedByDB: [String: Bool] = [:]
    var dbSecurityUsersExpandedByDB: [String: Bool] = [:]
    var dbSecurityRolesExpandedByDB: [String: Bool] = [:]
    var dbSecurityAppRolesExpandedByDB: [String: Bool] = [:]
    var dbSecuritySchemasExpandedByDB: [String: Bool] = [:]
    var dbSecurityUsersByDB: [String: [SecurityUserItem]] = [:]
    var dbSecurityRolesByDB: [String: [SecurityDatabaseRoleItem]] = [:]
    var dbSecurityAppRolesByDB: [String: [SecurityAppRoleItem]] = [:]
    var dbSecuritySchemasByDB: [String: [SecuritySchemaItem]] = [:]
    var dbSecurityLoadingByDB: [String: Bool] = [:]

    // Security sheets
    var showSecurityLoginSheet = false
    var securityLoginSheetEditName: String?
    var securityLoginSheetSessionID: UUID?
    var showSecurityUserSheet = false
    var securityUserSheetEditName: String?
    var securityUserSheetSessionID: UUID?
    var securityUserSheetDatabaseName: String?
    var showSecurityPGRoleSheet = false
    var securityPGRoleSheetEditName: String?
    var securityPGRoleSheetSessionID: UUID?

    // Database properties sheet
    var showDatabaseProperties = false
    var propertiesDatabaseName: String?
    var propertiesConnectionID: UUID?

    // Backup/Restore sheets
    var showBackupSheet = false
    var backupDatabaseName: String?
    var backupConnectionID: UUID?
    var showRestoreSheet = false
    var restoreDatabaseName: String?
    var restoreConnectionID: UUID?

    // Drop database confirmation
    var showDropDatabaseAlert = false
    var dropDatabaseTarget: DropDatabaseTarget?

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
    var showDropSecurityPrincipalAlert = false
    var dropSecurityPrincipalTarget: DropSecurityPrincipalTarget?

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

    struct LinkedServerItem: Identifiable, Hashable {
        let id: String
        let name: String
        let provider: String
        let dataSource: String
        let product: String
        let isDataAccessEnabled: Bool
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

    @ObservationIgnored private var searchDebounceTask: Task<Void, Never>?
    /// Tracks whether a debounce observer is already running.
    @ObservationIgnored private var isDebounceActive = false

    func setupSearchDebounce(proxy: ScrollViewProxy) {
        guard !isDebounceActive else { return }
        isDebounceActive = true

        // Use onChange-driven debounce via Task-based approach.
        // The caller should wire onChange(of: searchText) to call handleSearchTextChanged(proxy:).
    }

    func handleSearchTextChanged(proxy: ScrollViewProxy) {
        searchDebounceTask?.cancel()
        let newValue = searchText
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            debouncedSearchText = ""
            searchDebounceTask = Task {
                await Task.yield()
                guard !Task.isCancelled else { return }
                proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
            }
        } else {
            let pending = newValue
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
                debouncedSearchText = pending
                await Task.yield()
                guard !Task.isCancelled else { return }
                proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
            }
        }
    }

    func stopSearchDebounce() {
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
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

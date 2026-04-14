import SwiftUI
import EchoSense
import SQLServerKit
import PostgresKit

@MainActor @Observable
final class ObjectBrowserSidebarViewModel {
    var expandedServerIDs: Set<UUID> = []
    var selectedObjectID: String?
    var knownSessionIDs: Set<UUID> = []
    var recentlyConnectedIDs: Set<UUID> = []

    /// Maps connection ID → session ID for the last initialized session.
    /// Used to detect reconnects (same connection ID, new session ID).
    @ObservationIgnored internal var lastInitializedSessionID: [UUID: UUID] = [:]

    // Per-session state
    var expandedDatabasesBySession: [UUID: Set<String>] = [:]
    var expandedObjectGroupsBySession: [String: Set<SchemaObjectInfo.ObjectType>] = [:]
    var expandedObjectIDsBySession: [String: Set<String>] = [:]
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
    var hideOfflineDatabasesBySession: [UUID: Bool] = [:]

    // Agent Jobs state (per-connection, MSSQL only)
    var agentJobsExpandedBySession: [UUID: Bool] = [:]
    var agentJobsBySession: [UUID: [AgentJobItem]] = [:]
    var agentJobsLoadingBySession: [UUID: Bool] = [:]
    // Linked Servers state (per-connection, MSSQL only)
    var linkedServersExpandedBySession: [UUID: Bool] = [:]
    var linkedServersBySession: [UUID: [LinkedServerItem]] = [:]
    var linkedServersLoadingBySession: [UUID: Bool] = [:]

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

    // PostgreSQL Advanced Objects sidebar state (keyed by "connID-dbName")
    var advancedObjectsExpandedByDB: [String: Bool] = [:]

    // PostgreSQL Replication sidebar state (keyed by "connID-dbName")
    var replicationPubExpanded: [String: Bool] = [:]
    var replicationSubExpanded: [String: Bool] = [:]
    var replicationPubData: [String: [PostgresPublicationInfo]] = [:]
    var replicationSubData: [String: [PostgresSubscriptionInfo]] = [:]

    // SSIS (per-connection, MSSQL only)
    var ssisExpandedBySession: [UUID: Bool] = [:]
    var ssisFoldersBySession: [UUID: [SQLServerSSISFolder]] = [:]
    var ssisLoadingBySession: [UUID: Bool] = [:]

    // Database Snapshots (per-connection, MSSQL only)
    var databaseSnapshotsExpandedBySession: [UUID: Bool] = [:]
    var databaseSnapshotsBySession: [UUID: [SQLServerDatabaseSnapshot]] = [:]
    var databaseSnapshotsLoadingBySession: [UUID: Bool] = [:]

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

    func resetExpandedState(for session: ConnectionSession?, selectedSession: ConnectionSession?) {
        guard let targetSession = session ?? selectedSession else { return }
        let connID = targetSession.connection.id
        let prefix = connID.uuidString + "#"
        for key in expandedObjectIDsBySession.keys where key.hasPrefix(prefix) { expandedObjectIDsBySession.removeValue(forKey: key) }
        let defaults = defaultExpandedObjectTypes[connID] ?? Set(SchemaObjectInfo.ObjectType.allCases)
        for key in expandedObjectGroupsBySession.keys where key.hasPrefix(prefix) { expandedObjectGroupsBySession[key] = defaults }
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

    // Server Triggers (per-connection, MSSQL only)
    var serverTriggersExpandedBySession: [UUID: Bool] = [:]
    var serverTriggersBySession: [UUID: [ServerTriggerItem]] = [:]
    var serverTriggersLoadingBySession: [UUID: Bool] = [:]

    struct ServerTriggerItem: Identifiable, Hashable {
        let id: String
        let name: String
        let isDisabled: Bool
        let typeDescription: String
        let events: [String]
    }

    // Database DDL Triggers (keyed by "connID#dbName")
    var dbDDLTriggersExpandedByDB: [String: Bool] = [:]
    var dbDDLTriggersByDB: [String: [DatabaseDDLTriggerItem]] = [:]
    var dbDDLTriggersLoadingByDB: [String: Bool] = [:]

    struct DatabaseDDLTriggerItem: Identifiable, Hashable {
        let id: String
        let name: String
        let isDisabled: Bool
        let events: [String]
    }

    // Service Broker (keyed by "connID#dbName")
    var serviceBrokerExpandedByDB: [String: Bool] = [:]
    var serviceBrokerSubExpandedByDB: [String: Set<String>] = [:]
    var serviceBrokerLoadingByDB: [String: Bool] = [:]
    var serviceBrokerMessageTypesByDB: [String: [String]] = [:]
    var serviceBrokerContractsByDB: [String: [String]] = [:]
    var serviceBrokerQueuesByDB: [String: [String]] = [:]
    var serviceBrokerServicesByDB: [String: [String]] = [:]
    var serviceBrokerRoutesByDB: [String: [String]] = [:]
    var serviceBrokerBindingsByDB: [String: [String]] = [:]

    // External Resources / PolyBase (keyed by "connID#dbName")
    var externalResourcesExpandedByDB: [String: Bool] = [:]
    var externalResourcesSubExpandedByDB: [String: Set<String>] = [:]
    var externalResourcesLoadingByDB: [String: Bool] = [:]
    var externalDataSourcesByDB: [String: [String]] = [:]
    var externalTablesByDB: [String: [String]] = [:]
    var externalFileFormatsByDB: [String: [String]] = [:]
}

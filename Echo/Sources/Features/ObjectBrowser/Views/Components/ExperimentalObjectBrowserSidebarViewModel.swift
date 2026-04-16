import Foundation
import SQLServerKit

@MainActor @Observable
final class ObjectBrowserSidebarViewModel {
    var expandedNodeIDs: Set<String> = []
    var selectedNodeID: String?
    var hideOfflineDatabasesBySession: [UUID: Bool] = [:]
    var revealedNodeID: String?
    var revealRequestID = 0
    var highlightedNodeID: String?
    var highlightPulse = false
    var agentJobsBySession: [UUID: [AgentJobItem]] = [:]
    var agentJobsLoadingBySession: [UUID: Bool] = [:]
    var linkedServersBySession: [UUID: [LinkedServerItem]] = [:]
    var linkedServersLoadingBySession: [UUID: Bool] = [:]
    var ssisFoldersBySession: [UUID: [SQLServerSSISFolder]] = [:]
    var ssisLoadingBySession: [UUID: Bool] = [:]
    var databaseSnapshotsBySession: [UUID: [SQLServerDatabaseSnapshot]] = [:]
    var databaseSnapshotsLoadingBySession: [UUID: Bool] = [:]
    var serverTriggersBySession: [UUID: [ServerTriggerItem]] = [:]
    var serverTriggersLoadingBySession: [UUID: Bool] = [:]
    var securityLoginsBySession: [UUID: [SecurityLoginItem]] = [:]
    var securityServerRolesBySession: [UUID: [SecurityServerRoleItem]] = [:]
    var securityCredentialsBySession: [UUID: [SecurityCredentialItem]] = [:]
    var securityServerLoadingBySession: [UUID: Bool] = [:]
    var dbSecurityUsersByDB: [String: [SecurityUserItem]] = [:]
    var dbSecurityRolesByDB: [String: [SecurityDatabaseRoleItem]] = [:]
    var dbSecurityAppRolesByDB: [String: [SecurityAppRoleItem]] = [:]
    var dbSecuritySchemasByDB: [String: [SecuritySchemaItem]] = [:]
    var dbSecurityLoadingByDB: [String: Bool] = [:]
    var dbDDLTriggersByDB: [String: [DatabaseDDLTriggerItem]] = [:]
    var dbDDLTriggersLoadingByDB: [String: Bool] = [:]
    var serviceBrokerLoadingByDB: [String: Bool] = [:]
    var serviceBrokerMessageTypesByDB: [String: [String]] = [:]
    var serviceBrokerContractsByDB: [String: [String]] = [:]
    var serviceBrokerQueuesByDB: [String: [String]] = [:]
    var serviceBrokerServicesByDB: [String: [String]] = [:]
    var serviceBrokerRoutesByDB: [String: [String]] = [:]
    var serviceBrokerBindingsByDB: [String: [String]] = [:]
    var externalResourcesLoadingByDB: [String: Bool] = [:]
    var externalDataSourcesByDB: [String: [String]] = [:]
    var externalTablesByDB: [String: [String]] = [:]
    var externalFileFormatsByDB: [String: [String]] = [:]

    @ObservationIgnored var initializedConnectionIDs: Set<UUID> = []

    func synchronizeDefaults(
        sessions: [ConnectionSession],
        autoExpandSectionsForDatabaseType: (DatabaseType) -> Set<SidebarAutoExpandSection>
    ) {
        let validConnectionIDs = Set(sessions.map(\.connection.id))
        initializedConnectionIDs = initializedConnectionIDs.intersection(validConnectionIDs)
        var expanded = expandedNodeIDs

        for session in sessions where !initializedConnectionIDs.contains(session.connection.id) {
            initializedConnectionIDs.insert(session.connection.id)

            expanded.insert(Self.serverNodeID(connectionID: session.connection.id))

            let autoExpand = autoExpandSectionsForDatabaseType(session.connection.databaseType)
            if autoExpand.contains(.databases) {
                expanded.insert(Self.databasesFolderNodeID(connectionID: session.connection.id))
            }
            if autoExpand.contains(.security) {
                expanded.insert(
                    Self.serverFolderNodeID(connectionID: session.connection.id, kind: .security)
                )
            }
            if autoExpand.contains(.management) {
                expanded.insert(
                    Self.serverFolderNodeID(connectionID: session.connection.id, kind: .management)
                )
            }
        }

        expandedNodeIDs = expanded
    }

    func setExpanded(_ isExpanded: Bool, nodeID: String) {
        var expanded = expandedNodeIDs
        if isExpanded {
            expanded.insert(nodeID)
        } else {
            expanded.remove(nodeID)
        }
        expandedNodeIDs = expanded
    }

    func toggleExpanded(nodeID: String) -> Bool {
        var expanded = expandedNodeIDs
        if expanded.contains(nodeID) {
            expanded.remove(nodeID)
            expandedNodeIDs = expanded
            return false
        } else {
            expanded.insert(nodeID)
            expandedNodeIDs = expanded
            return true
        }
    }

    func isExpanded(_ nodeID: String) -> Bool {
        expandedNodeIDs.contains(nodeID)
    }

    func revealAndPulse(nodeID: String) {
        revealedNodeID = nodeID
        revealRequestID &+= 1
        highlightedNodeID = nodeID
        highlightPulse.toggle()
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

    struct ServerTriggerItem: Identifiable, Hashable {
        let id: String
        let name: String
        let isDisabled: Bool
        let typeDescription: String
        let events: [String]
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

    struct DatabaseDDLTriggerItem: Identifiable, Hashable {
        let id: String
        let name: String
        let isDisabled: Bool
        let events: [String]
    }
}

extension ObjectBrowserSidebarViewModel {
    static func serverNodeID(connectionID: UUID) -> String {
        "\(connectionID.uuidString)#server"
    }

    static func databasesFolderNodeID(connectionID: UUID) -> String {
        "\(connectionID.uuidString)#folder#databases"
    }

    static func databaseNodeID(connectionID: UUID, databaseName: String) -> String {
        ExplorerSidebarIdentity.database(connectionID: connectionID, databaseName: databaseName)
    }

    static func objectGroupNodeID(
        connectionID: UUID,
        databaseName: String,
        objectType: SchemaObjectInfo.ObjectType
    ) -> String {
        "\(connectionID.uuidString)#db#\(databaseName)#group#\(objectType.rawValue)"
    }

    static func serverFolderNodeID(
        connectionID: UUID,
        kind: ObjectBrowserServerFolderKind
    ) -> String {
        "\(connectionID.uuidString)#server-folder#\(kind.rawValue)"
    }

    static func securitySectionNodeID(
        connectionID: UUID,
        kind: ObjectBrowserSecuritySectionKind,
        parentID: String
    ) -> String {
        "\(parentID)#security-section#\(connectionID.uuidString)#\(kind.rawValue)"
    }

    static func securityLeafNodeID(
        connectionID: UUID,
        parentID: String,
        kind: ObjectBrowserSecuritySectionKind,
        name: String
    ) -> String {
        "\(parentID)#security-leaf#\(connectionID.uuidString)#\(kind.rawValue)#\(name)"
    }

    static func actionNodeID(
        connectionID: UUID,
        parentID: String?,
        kind: ObjectBrowserActionKind
    ) -> String {
        "\(parentID ?? connectionID.uuidString)#action#\(kind.rawValue)"
    }

    static func databaseFolderNodeID(
        connectionID: UUID,
        databaseName: String,
        kind: ObjectBrowserDatabaseFolderKind
    ) -> String {
        "\(connectionID.uuidString)#db#\(databaseName)#folder#\(kind.rawValue)"
    }

    static func databaseSubfolderNodeID(parentID: String, title: String) -> String {
        "\(parentID)#subfolder#\(title)"
    }

    static func databaseItemNodeID(parentID: String, title: String) -> String {
        "\(parentID)#item#\(title)"
    }

    func databaseStorageKey(connectionID: UUID, databaseName: String) -> String {
        "\(connectionID.uuidString)#\(databaseName)"
    }

    static func infoNodeID(parentID: String, title: String) -> String {
        "\(parentID)#info#\(title)"
    }

    static func loadingNodeID(parentID: String) -> String {
        "\(parentID)#loading"
    }
}

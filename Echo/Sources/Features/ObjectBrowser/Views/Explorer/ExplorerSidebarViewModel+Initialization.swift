import SwiftUI
import EchoSense

extension ObjectBrowserSidebarViewModel {

    // MARK: - Session State Initialization

    func initializeSessionState(for session: ConnectionSession, autoExpandSections: Set<SidebarAutoExpandSection> = [.databases]) {
        let connID = session.connection.id
        let sessionID = session.id
        // Detect reconnect: same connection ID but different session ID
        let isNewSession = lastInitializedSessionID[connID] != sessionID
        let prefix = connID.uuidString + "#"
        if isNewSession {
            lastInitializedSessionID[connID] = sessionID
            // Bulk-clear stale expansion state (single assignment per dictionary instead of per-key removal)
            expandedObjectGroupsBySession = expandedObjectGroupsBySession.filter { !$0.key.hasPrefix(prefix) }
            expandedDatabasesBySession.removeValue(forKey: connID)
            expandedObjectIDsBySession = expandedObjectIDsBySession.filter { !$0.key.hasPrefix(prefix) }
            databasesFolderExpandedBySession.removeValue(forKey: connID)
            managementFolderExpandedBySession.removeValue(forKey: connID)
            agentJobsExpandedBySession.removeValue(forKey: connID)
            // Clear security state on reconnect
            securityFolderExpandedBySession.removeValue(forKey: connID)
            securityLoginsExpandedBySession.removeValue(forKey: connID)
            securityServerRolesExpandedBySession.removeValue(forKey: connID)
            securityCredentialsExpandedBySession.removeValue(forKey: connID)
            securityLoginsBySession.removeValue(forKey: connID)
            securityServerRolesBySession.removeValue(forKey: connID)
            securityCredentialsBySession.removeValue(forKey: connID)
            securityServerLoadingBySession.removeValue(forKey: connID)
            // Clear loaded-once tracking for this connection
            databaseSchemaLoadedOnce = databaseSchemaLoadedOnce.filter { !$0.hasPrefix(prefix) }
            // Clear database-level security state (bulk filter)
            dbSecurityExpandedByDB = dbSecurityExpandedByDB.filter { !$0.key.hasPrefix(prefix) }
            dbSecurityUsersByDB = dbSecurityUsersByDB.filter { !$0.key.hasPrefix(prefix) }
            dbSecurityRolesByDB = dbSecurityRolesByDB.filter { !$0.key.hasPrefix(prefix) }
            dbSecurityAppRolesByDB = dbSecurityAppRolesByDB.filter { !$0.key.hasPrefix(prefix) }
            dbSecuritySchemasByDB = dbSecuritySchemasByDB.filter { !$0.key.hasPrefix(prefix) }
            dbSecurityLoadingByDB = dbSecurityLoadingByDB.filter { !$0.key.hasPrefix(prefix) }
        }

        // Compute and cache the default expanded object types from sidebar settings.
        var defaultGroups = Set<SchemaObjectInfo.ObjectType>()
        for section in autoExpandSections {
            if let objectType = section.objectType {
                defaultGroups.insert(objectType)
            }
        }
        let previousDefaultGroups = defaultExpandedObjectTypes[connID]
        defaultExpandedObjectTypes[connID] = defaultGroups

        if previousDefaultGroups != nil, previousDefaultGroups != defaultGroups {
            expandedObjectGroupsBySession = expandedObjectGroupsBySession.filter { !$0.key.hasPrefix(prefix) }
        }

        databasesFolderExpandedBySession[connID] = autoExpandSections.contains(.databases)
        managementFolderExpandedBySession[connID] = autoExpandSections.contains(.management)
        agentJobsExpandedBySession[connID] = autoExpandSections.contains(.management)
        securityFolderExpandedBySession[connID] = autoExpandSections.contains(.security)
    }
}

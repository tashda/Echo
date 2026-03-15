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
            // Clear stale expansion state so settings are re-applied
            for key in expandedObjectGroupsBySession.keys where key.hasPrefix(prefix) { expandedObjectGroupsBySession.removeValue(forKey: key) }
            expandedDatabasesBySession.removeValue(forKey: connID)
            for key in expandedObjectIDsBySession.keys where key.hasPrefix(prefix) { expandedObjectIDsBySession.removeValue(forKey: key) }
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
            let prefix = connID.uuidString + "#"
            databaseSchemaLoadedOnce = databaseSchemaLoadedOnce.filter { !$0.hasPrefix(prefix) }
            // Clear database-level security state
            for key in dbSecurityExpandedByDB.keys where key.hasPrefix(prefix) { dbSecurityExpandedByDB.removeValue(forKey: key) }
            for key in dbSecurityUsersByDB.keys where key.hasPrefix(prefix) { dbSecurityUsersByDB.removeValue(forKey: key) }
            for key in dbSecurityRolesByDB.keys where key.hasPrefix(prefix) { dbSecurityRolesByDB.removeValue(forKey: key) }
            for key in dbSecurityAppRolesByDB.keys where key.hasPrefix(prefix) { dbSecurityAppRolesByDB.removeValue(forKey: key) }
            for key in dbSecuritySchemasByDB.keys where key.hasPrefix(prefix) { dbSecuritySchemasByDB.removeValue(forKey: key) }
            for key in dbSecurityLoadingByDB.keys where key.hasPrefix(prefix) { dbSecurityLoadingByDB.removeValue(forKey: key) }
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
            for key in expandedObjectGroupsBySession.keys where key.hasPrefix(prefix) {
                expandedObjectGroupsBySession.removeValue(forKey: key)
            }
        }

        databasesFolderExpandedBySession[connID] = autoExpandSections.contains(.databases)
        managementFolderExpandedBySession[connID] = autoExpandSections.contains(.management)
        agentJobsExpandedBySession[connID] = autoExpandSections.contains(.management)
        securityFolderExpandedBySession[connID] = autoExpandSections.contains(.security)
    }
}

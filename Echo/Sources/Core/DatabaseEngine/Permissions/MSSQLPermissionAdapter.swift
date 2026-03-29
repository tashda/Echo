import Foundation
import SQLServerKit

/// Adapts ``ServerPermissions`` from sqlserver-nio to the unified ``DatabasePermissionProviding`` protocol.
nonisolated struct MSSQLPermissionAdapter: DatabasePermissionProviding, Sendable {
    let permissions: ServerPermissions

    // Common
    var canCreateDatabases: Bool { permissions.canCreateDatabases }
    var canManageRoles: Bool { permissions.canManageLogins }
    var canManageServerState: Bool { permissions.canViewServerState }
    var canBackupRestore: Bool { permissions.canBackupRestore }

    // MSSQL-specific
    var canManageAgent: Bool { permissions.canManageAgent }
    var canViewAgentJobs: Bool { permissions.canViewAgentJobs }
    var canConfigureDatabaseMail: Bool { permissions.canConfigureDatabaseMail }
    var canManageLinkedServers: Bool { permissions.canManageLinkedServers }

    // Postgres-specific (not applicable)
    var canManageExtensions: Bool { false }
    var canVacuumFull: Bool { false }
    var canCreateSchemas: Bool { permissions.isSysadmin }

    func disabledReason(for capability: String) -> String {
        "Requires elevated SQL Server permissions for \(capability)"
    }
}

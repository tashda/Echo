import Foundation
import PostgresKit

/// Adapts ``PostgresPermissions`` from postgres-wire to the unified ``DatabasePermissionProviding`` protocol.
nonisolated struct PostgresPermissionAdapter: DatabasePermissionProviding, Sendable {
    let permissions: PostgresPermissions

    // Common
    var canCreateDatabases: Bool { permissions.canManageDatabases }
    var canManageRoles: Bool { permissions.canManageRoles }
    var canManageServerState: Bool { permissions.isSuperuser }
    var canBackupRestore: Bool { permissions.isSuperuser }

    // MSSQL-specific (not applicable)
    var canManageAgent: Bool { false }
    var canViewAgentJobs: Bool { false }
    var canConfigureDatabaseMail: Bool { false }
    var canManageLinkedServers: Bool { false }

    // Postgres-specific
    var canManageExtensions: Bool { permissions.canManageExtensions }
    var canVacuumFull: Bool { permissions.canVacuumFull }
    var canCreateSchemas: Bool { permissions.canCreateSchemas }

    func disabledReason(for capability: String) -> String {
        "Requires PostgreSQL superuser or elevated role for \(capability)"
    }
}

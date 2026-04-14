import Foundation

/// Unified protocol for checking the current user's effective permissions.
///
/// Both MSSQL and PostgreSQL adapters conform to this protocol, allowing views
/// to check permissions without knowing the dialect. Properties that don't apply
/// to a dialect return `false` (e.g. `canManageAgent` is always `false` for Postgres).
///
/// Permissions are fetched once at connection time and cached on `ConnectionSession`.
/// Views use the fail-open pattern: `session.permissions?.canDoX ?? true` — if
/// permissions haven't loaded yet, controls stay enabled.
public nonisolated protocol DatabasePermissionProviding: Sendable {
    // Common
    var canCreateDatabases: Bool { get }
    var canManageRoles: Bool { get }
    var canManageServerState: Bool { get }
    var canBackupRestore: Bool { get }

    // MSSQL-specific (false for Postgres)
    var canManageAgent: Bool { get }
    var canViewAgentJobs: Bool { get }
    var canConfigureDatabaseMail: Bool { get }
    var canManageLinkedServers: Bool { get }

    // Postgres-specific (false for MSSQL)
    var canManageExtensions: Bool { get }
    var canVacuumFull: Bool { get }
    var canCreateSchemas: Bool { get }

    /// Human-readable reason why a control is disabled.
    func disabledReason(for capability: String) -> String
}

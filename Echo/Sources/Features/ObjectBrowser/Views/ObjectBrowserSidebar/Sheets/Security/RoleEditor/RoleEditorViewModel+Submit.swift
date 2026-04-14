import Foundation
import SQLServerKit

extension RoleEditorViewModel {

    /// Applies changes to the server without closing. Returns true on success.
    @discardableResult
    func apply(session: ConnectionSession) async -> Bool {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return false
        }

        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Role name is required"
            return false
        }

        isSubmitting = true
        errorMessage = nil

        let handle = activityEngine?.begin(
            isEditing ? "Saving role \(name)" : "Creating role \(name)",
            connectionSessionID: session.id
        )

        do {
            let sec = mssql.security
            _ = try? await session.session.sessionForDatabase(databaseName)

            if !isEditing {
                let options = owner.isEmpty ? RoleOptions() : RoleOptions(owner: owner)
                try await sec.createRole(name: name, options: options)
            }

            if hasLoadedMembers {
                try await syncMembers(sec: sec, roleName: name)
            }

            if hasLoadedSecurables {
                try await syncSecurables(sec: sec, roleName: name)
            }

            handle?.succeed()
            isSubmitting = false
            takeSnapshot()
            return true
        } catch {
            handle?.fail(error.localizedDescription)
            isSubmitting = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Applies changes and closes the window on success.
    func saveAndClose(session: ConnectionSession) async {
        let success = await apply(session: session)
        if success {
            didComplete = true
        }
    }

    // MARK: - Member Sync

    private func syncMembers(sec: SQLServerSecurityClient, roleName: String) async throws {
        for entry in memberEntries {
            if entry.isMember && !entry.originallyMember {
                try await sec.addUserToRole(user: entry.name, role: roleName)
            } else if !entry.isMember && entry.originallyMember {
                try await sec.removeUserFromRole(user: entry.name, role: roleName)
            }
        }
    }

    // MARK: - Securables Sync

    private func syncSecurables(sec: SQLServerSecurityClient, roleName: String) async throws {
        for entry in securableEntries {
            for perm in entry.permissions {
                let changed = perm.isGranted != perm.originalState.isGranted ||
                    perm.withGrantOption != perm.originalState.withGrantOption ||
                    perm.isDenied != perm.originalState.isDenied
                guard changed else { continue }

                let objectName = entry.securable.objectName
                guard let permission = Permission(rawValue: perm.permission) else { continue }

                // Revoke any existing state first if changed
                if perm.originalState.isGranted || perm.originalState.isDenied {
                    try await sec.revokePermission(
                        permission: permission,
                        on: objectName,
                        from: roleName,
                        cascadeOption: true
                    )
                }

                // Apply new state
                if perm.isDenied {
                    try await sec.denyPermission(permission: permission, on: objectName, to: roleName)
                } else if perm.isGranted {
                    try await sec.grantPermission(
                        permission: permission,
                        on: objectName,
                        to: roleName,
                        withGrantOption: perm.withGrantOption
                    )
                }
            }
        }
    }
}

import Foundation
import SQLServerKit

extension PermissionManagerViewModel {

    /// Applies permission changes to the server. Returns true on success.
    @discardableResult
    func apply(session: ConnectionSession) async -> Bool {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return false
        }

        let principal = selectedPrincipalName
        guard !principal.isEmpty else {
            errorMessage = "No principal selected"
            return false
        }

        isSubmitting = true
        errorMessage = nil

        let handle = activityEngine?.begin(
            "Updating permissions for \(principal)",
            connectionSessionID: session.id
        )

        do {
            _ = try? await session.session.sessionForDatabase(databaseName)

            for entry in securableEntries {
                let objectRef = buildObjectReference(for: entry.securable)

                for perm in entry.permissions {
                    let changed = perm.isGranted != perm.originalState.isGranted ||
                        perm.withGrantOption != perm.originalState.withGrantOption ||
                        perm.isDenied != perm.originalState.isDenied
                    guard changed else { continue }

                    // Revoke existing state first if there was one
                    if perm.originalState.isGranted || perm.originalState.isDenied {
                        try await mssql.security.revokePermission(
                            permission: Permission(rawValue: perm.permission) ?? .select,
                            on: objectRef,
                            from: principal,
                            cascadeOption: true
                        )
                    }

                    // Apply new state
                    if perm.isDenied {
                        try await mssql.security.denyPermission(
                            permission: Permission(rawValue: perm.permission) ?? .select,
                            on: objectRef,
                            to: principal
                        )
                    } else if perm.isGranted {
                        try await mssql.security.grantPermission(
                            permission: Permission(rawValue: perm.permission) ?? .select,
                            on: objectRef,
                            to: principal,
                            withGrantOption: perm.withGrantOption
                        )
                    }
                }
            }

            handle?.succeed()
            isSubmitting = false

            // Reload to get fresh state from server
            await loadSecurables(session: session)
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

    // MARK: - Helpers

    private func buildObjectReference(for ref: SecurableReference) -> String {
        if ref.typeName == "Database" {
            return "DATABASE"
        }
        if ref.typeName == "Schema" {
            return "SCHEMA::[\(ref.objectName.replacingOccurrences(of: "]", with: "]]"))]"
        }
        if let schema = ref.schemaName, !schema.isEmpty {
            let escapedSchema = "[\(schema.replacingOccurrences(of: "]", with: "]]"))]"
            let escapedName = "[\(ref.objectName.replacingOccurrences(of: "]", with: "]]"))]"
            return "\(escapedSchema).\(escapedName)"
        }
        return "[\(ref.objectName.replacingOccurrences(of: "]", with: "]]"))]"
    }
}

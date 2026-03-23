import Foundation
import SQLServerKit

extension UserEditorViewModel {

    /// Applies changes to the server without closing. Returns true on success.
    @discardableResult
    func apply(session: ConnectionSession) async -> Bool {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return false
        }

        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "User name is required"
            return false
        }

        isSubmitting = true
        errorMessage = nil

        let handle = activityEngine?.begin(
            isEditing ? "Saving user \(name)" : "Creating user \(name)",
            connectionSessionID: session.id
        )

        do {
            let sec = mssql.security
            _ = try? await session.session.sessionForDatabase(databaseName)

            if isEditing {
                try await submitAlterUser(sec: sec, name: name)
            } else {
                try await submitCreateUser(sec: sec, name: name)
            }

            if hasLoadedRoles {
                try await syncRoleMemberships(sec: sec, userName: name)
            }

            if hasLoadedSchemas {
                try await syncSchemaOwnership(sec: sec, userName: name)
            }

            if hasLoadedSecurables {
                try await syncSecurables(sec: sec, userName: name)
            }

            if hasLoadedExtendedProperties {
                try await syncExtendedProperties(mssql: mssql, userName: name)
            }

            handle?.succeed()
            isSubmitting = false
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

    // MARK: - Create

    private func submitCreateUser(sec: SQLServerSecurityClient, name: String) async throws {
        let dbUserType: DatabaseUserType
        switch userType {
        case .mappedToLogin:
            dbUserType = .mappedToLogin(loginName)
        case .withPassword:
            dbUserType = .withPassword(password)
        case .withoutLogin:
            dbUserType = .withoutLogin
        case .windowsUser:
            dbUserType = .windowsUser(loginName)
        case .mappedToCertificate:
            dbUserType = .mappedToCertificate(selectedCertificate)
        case .mappedToAsymmetricKey:
            dbUserType = .mappedToAsymmetricKey(selectedAsymmetricKey)
        }

        let options = UserOptions(
            defaultSchema: defaultSchema.isEmpty ? nil : defaultSchema,
            defaultLanguage: defaultLanguage.isEmpty ? nil : defaultLanguage,
            allowEncryptedValueModifications: allowEncryptedValueModifications
        )

        try await sec.createUser(name: name, type: dbUserType, options: options)
    }

    // MARK: - Alter

    private func submitAlterUser(sec: SQLServerSecurityClient, name: String) async throws {
        try await sec.alterUser(
            name: name,
            defaultSchema: defaultSchema.isEmpty ? nil : defaultSchema
        )
    }

    // MARK: - Role Membership Sync

    private func syncRoleMemberships(sec: SQLServerSecurityClient, userName: String) async throws {
        for role in roleEntries where role.name != "public" {
            if role.isMember && !role.originallyMember {
                try await sec.addUserToRole(user: userName, role: role.name)
            } else if !role.isMember && role.originallyMember {
                try await sec.removeUserFromRole(user: userName, role: role.name)
            }
        }
    }

    // MARK: - Schema Ownership Sync

    private func syncSchemaOwnership(sec: SQLServerSecurityClient, userName: String) async throws {
        for schema in schemaEntries where !schema.isSystemSchema {
            if schema.isOwned && !schema.originallyOwned {
                try await sec.alterAuthorizationOnSchema(schema: schema.name, principal: userName)
            } else if !schema.isOwned && schema.originallyOwned {
                try await sec.alterAuthorizationOnSchema(schema: schema.name, principal: "dbo")
            }
        }
    }

    // MARK: - Securables Sync

    private func syncSecurables(sec: SQLServerSecurityClient, userName: String) async throws {
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
                        from: userName,
                        cascadeOption: true
                    )
                }

                // Apply new state
                if perm.isDenied {
                    try await sec.denyPermission(permission: permission, on: objectName, to: userName)
                } else if perm.isGranted {
                    try await sec.grantPermission(
                        permission: permission,
                        on: objectName,
                        to: userName,
                        withGrantOption: perm.withGrantOption
                    )
                }
            }
        }
    }

    // MARK: - Extended Properties Sync

    private func syncExtendedProperties(mssql: MSSQLSession, userName: String) async throws {
        let ep = mssql.extendedProperties

        for entry in extendedPropertyEntries {
            if entry.isDeleted && !entry.isNew {
                // Delete existing property
                if let origName = entry.originalName {
                    try await ep.dropForUser(userName: userName, name: origName)
                }
            } else if entry.isNew && !entry.isDeleted && !entry.name.isEmpty {
                // Add new property
                try await ep.addForUser(userName: userName, name: entry.name, value: entry.value)
            } else if !entry.isNew && !entry.isDeleted {
                // Update if changed
                let nameChanged = entry.name != entry.originalName
                let valueChanged = entry.value != entry.originalValue

                if nameChanged, let origName = entry.originalName {
                    // Rename = drop + add
                    try await ep.dropForUser(userName: userName, name: origName)
                    try await ep.addForUser(userName: userName, name: entry.name, value: entry.value)
                } else if valueChanged {
                    try await ep.updateForUser(userName: userName, name: entry.name, value: entry.value)
                }
            }
        }
    }
}

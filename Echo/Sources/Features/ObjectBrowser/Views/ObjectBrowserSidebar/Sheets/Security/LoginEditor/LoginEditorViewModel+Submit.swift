import Foundation
import SQLServerKit

extension LoginEditorViewModel {

    /// Applies changes to the server without closing. Returns true on success.
    @discardableResult
    func apply(session: ConnectionSession) async -> Bool {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return false
        }

        let name = loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Login name is required"
            return false
        }

        isSubmitting = true
        errorMessage = nil

        let handle = activityEngine?.begin(
            isEditing ? "Saving login \(name)" : "Creating login \(name)",
            connectionSessionID: session.id
        )

        do {
            let ssec = mssql.serverSecurity

            if isEditing {
                try await submitAlterLogin(ssec: ssec, name: name)
            } else {
                try await submitCreateLogin(ssec: ssec, name: name)
            }

            if hasLoadedRoles {
                try await syncRoleMemberships(ssec: ssec, loginName: name)
            }

            if hasLoadedMappings {
                try await syncUserMappings(ssec: ssec, loginName: name)
            }

            if hasLoadedSecurables {
                try await syncServerPermissions(ssec: ssec, loginName: name)
            }

            handle?.succeed()
            isSubmitting = false
            password = ""
            confirmPassword = ""

            // Reload mappings to get actual server state (userNames, schemas)
            if hasLoadedMappings {
                await reloadMappingsAfterApply(session: session)
            }

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

    // MARK: - Create

    private func submitCreateLogin(ssec: SQLServerServerSecurityClient, name: String) async throws {
        if authType == .sql {
            try await ssec.createSqlLogin(name: name, password: password, options: .init(
                defaultDatabase: defaultDatabase,
                defaultLanguage: defaultLanguage.isEmpty ? nil : defaultLanguage,
                checkPolicy: enforcePasswordPolicy,
                checkExpiration: enforcePasswordExpiration
            ))
        } else {
            try await ssec.createWindowsLogin(name: name)
        }

        if !loginEnabled {
            try await ssec.enableLogin(name: name, enabled: false)
        }
    }

    // MARK: - Alter

    private func submitAlterLogin(ssec: SQLServerServerSecurityClient, name: String) async throws {
        if authType == .sql && !password.isEmpty {
            try await ssec.setLoginPassword(name: name, newPassword: password)
        }

        try await ssec.enableLogin(name: name, enabled: loginEnabled)
        try await ssec.alterLogin(name: name, options: .init(
            defaultDatabase: defaultDatabase,
            defaultLanguage: defaultLanguage.isEmpty ? nil : defaultLanguage,
            checkPolicy: authType == .sql ? enforcePasswordPolicy : nil,
            checkExpiration: authType == .sql ? enforcePasswordExpiration : nil
        ))
    }

    // MARK: - Role Membership Sync

    private func syncRoleMemberships(ssec: SQLServerServerSecurityClient, loginName: String) async throws {
        for role in roleEntries where role.name != "public" {
            if role.isMember && !role.originallyMember {
                try await ssec.addMemberToServerRole(role: role.name, principal: loginName)
            } else if !role.isMember && role.originallyMember {
                try await ssec.removeMemberFromServerRole(role: role.name, principal: loginName)
            }
        }
    }

    // MARK: - User Mapping Sync

    private func syncUserMappings(ssec: SQLServerServerSecurityClient, loginName: String) async throws {
        for entry in mappingEntries {
            if entry.isMapped && !entry.originallyMapped {
                // Create new mapping
                do {
                    try await ssec.mapLoginToDatabase(login: loginName, database: entry.databaseName)
                } catch {
                    let msg = error.localizedDescription
                    if !msg.contains("already exists") { throw error }
                }

                // Apply role changes for newly mapped databases
                if let roles = databaseRolesPerDB[entry.databaseName] {
                    let userName = entry.userName ?? loginName
                    for role in roles where role.isMember && !role.originallyMember {
                        try await ssec.addUserToDatabaseRole(
                            database: entry.databaseName, userName: userName, role: role.roleName
                        )
                    }
                }
            } else if !entry.isMapped && entry.originallyMapped {
                // Remove mapping
                try await ssec.unmapLoginFromDatabase(
                    login: loginName, database: entry.databaseName, userName: entry.userName
                )
            } else if entry.isMapped && entry.originallyMapped {
                // Sync role changes for existing mappings
                if let roles = databaseRolesPerDB[entry.databaseName] {
                    let userName = entry.userName ?? loginName
                    for role in roles {
                        if role.isMember && !role.originallyMember {
                            try await ssec.addUserToDatabaseRole(
                                database: entry.databaseName, userName: userName, role: role.roleName
                            )
                        } else if !role.isMember && role.originallyMember {
                            try await ssec.removeUserFromDatabaseRole(
                                database: entry.databaseName, userName: userName, role: role.roleName
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reload After Apply

    private func reloadMappingsAfterApply(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession,
              let existingName = existingLoginName else { return }

        do {
            let mappings = try await mssql.serverSecurity.listLoginDatabaseMappings(login: existingName)
            let mappedSet = Dictionary(
                mappings.map { ($0.databaseName.lowercased(), $0) },
                uniquingKeysWith: { first, _ in first }
            )

            mappingEntries = availableDatabases.map { db in
                if let mapping = mappedSet[db.lowercased()] {
                    LoginEditorMappingEntry(
                        databaseName: db, isMapped: true, originallyMapped: true,
                        userName: mapping.userName, defaultSchema: mapping.defaultSchema
                    )
                } else {
                    LoginEditorMappingEntry(
                        databaseName: db, isMapped: false, originallyMapped: false,
                        userName: nil, defaultSchema: nil
                    )
                }
            }

            // Reload DB roles for any database that was selected, to get fresh originallyMember values
            databaseRolesPerDB.removeAll()
            if let selectedDB = selectedMappingDatabase {
                await loadDatabaseRoles(database: selectedDB, session: session)
            }
        } catch { }
    }

    // MARK: - Server Permission Sync

    private func syncServerPermissions(ssec: SQLServerServerSecurityClient, loginName: String) async throws {
        // Handle CONNECT SQL separately from the main loop
        if let originalConnectState = snapshot?.permissionStates[ServerPermissionName.connectSql.rawValue] {
            let originalState = ConnectPermissionState(
                isGranted: originalConnectState.isGranted,
                isDenied: originalConnectState.isDenied
            )
            let currentState = permissionConnectToEngine

            if originalState != currentState {
                // Revoke existing state first
                if originalState != .unspecified {
                    try await ssec.revokeRaw(permission: ServerPermissionName.connectSql.rawValue, from: loginName, cascade: false)
                }

                // Apply new state
                switch currentState {
                case .granted:
                    try await ssec.grantRaw(permission: ServerPermissionName.connectSql.rawValue, to: loginName, withGrantOption: false)
                case .denied:
                    try await ssec.denyRaw(permission: ServerPermissionName.connectSql.rawValue, to: loginName)
                case .unspecified:
                    // Nothing to do if current state is unspecified after revoke
                    break
                }
            }
        }
        
        for perm in serverPermissions where perm.permission != ServerPermissionName.connectSql.rawValue {
            let changed = perm.isGranted != perm.originalState.isGranted ||
                perm.withGrantOption != perm.originalState.withGrantOption ||
                perm.isDenied != perm.originalState.isDenied
            guard changed else { continue }

            // Revoke existing state first if there was one
            if perm.originalState.isGranted || perm.originalState.isDenied {
                try await ssec.revokeRaw(permission: perm.permission, from: loginName, cascade: true)
            }

            // Apply new state
            if perm.isDenied {
                try await ssec.denyRaw(permission: perm.permission, to: loginName)
            } else if perm.isGranted {
                try await ssec.grantRaw(permission: perm.permission, to: loginName, withGrantOption: perm.withGrantOption)
            }
        }
    }
}

private extension ConnectSQLPermissionState {
    init(isGranted: Bool, isDenied: Bool) {
        if isGranted { self = .granted }
        else if isDenied { self = .denied }
        else { self = .unspecified }
    }
}

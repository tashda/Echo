import SwiftUI
import SQLServerKit

extension SecurityLoginSheet {

    // MARK: - Data Loading

    func loadInitialData() async {
        guard let mssql = session.session as? MSSQLSession else {
            isLoading = false
            return
        }

        // Load databases
        do {
            let dbs = try await session.session.listDatabases()
            await MainActor.run { availableDatabases = dbs.sorted() }
        } catch { }

        // Load server roles
        loadingRoles = true
        do {
            let ssec = mssql.serverSecurity
            let roles = try await ssec.listServerRoles()
            var entries = roles.map { role in
                RoleEntry(name: role.name, isFixed: role.isFixed, isMember: false)
            }

            // If editing, check which roles this login is a member of
            if let loginName = existingLoginName {
                for i in entries.indices {
                    let members = try await ssec.listServerRoleMembers(role: entries[i].name)
                    if members.contains(where: { $0.caseInsensitiveCompare(loginName) == .orderedSame }) {
                        entries[i].isMember = true
                    }
                }
                entries.sort { a, b in
                    if a.isMember != b.isMember { return a.isMember }
                    return a.name < b.name
                }
            }

            await MainActor.run {
                availableServerRoles = entries
                loadingRoles = false
            }
        } catch {
            await MainActor.run { loadingRoles = false }
        }

        // If editing, load existing login properties and database mappings
        if let existingName = existingLoginName {
            do {
                let ssec = mssql.serverSecurity
                let logins = try await ssec.listLogins(includeSystemLogins: true)
                if let login = logins.first(where: { $0.name.caseInsensitiveCompare(existingName) == .orderedSame }) {
                    await MainActor.run {
                        loginName = login.name
                        loginEnabled = !login.isDisabled
                        defaultDatabase = login.defaultDatabase ?? "master"
                        defaultLanguage = login.defaultLanguage ?? ""
                        enforcePasswordPolicy = login.isPolicyChecked ?? true
                        enforcePasswordExpiration = login.isExpirationChecked ?? false
                        switch login.type {
                        case .sql: authType = .sql
                        default: authType = .windows
                        }
                    }
                }
            } catch { }

            // Load database mappings
            loadingMappings = true
            do {
                let ssec = mssql.serverSecurity
                let mappings = try await ssec.listLoginDatabaseMappings(login: existingName)
                let mappedSet = Dictionary(uniqueKeysWithValues: mappings.map { ($0.databaseName, $0) })
                let allDbs = availableDatabases

                await MainActor.run {
                    databaseMappings = mappings
                    databaseMappingEntries = allDbs.map { db in
                        if let mapping = mappedSet[db] {
                            return DatabaseMappingEntry(databaseName: db, isMapped: true, userName: mapping.userName, defaultSchema: mapping.defaultSchema)
                        } else {
                            return DatabaseMappingEntry(databaseName: db, isMapped: false, userName: nil, defaultSchema: nil)
                        }
                    }
                    loadingMappings = false
                }
            } catch {
                await MainActor.run { loadingMappings = false }
            }
        }

        await MainActor.run { isLoading = false }
    }

    // MARK: - Database Mapping Actions

    func mapToDatabase(database: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let name = existingLoginName ?? loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        do {
            let ssec = mssql.serverSecurity
            try await ssec.mapLoginToDatabase(login: name, database: database)
            await reloadMappingEntries()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func unmapFromDatabase(database: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let name = existingLoginName ?? loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let entry = databaseMappingEntries.first(where: { $0.databaseName == database })
        do {
            let ssec = mssql.serverSecurity
            try await ssec.unmapLoginFromDatabase(login: name, database: database, userName: entry?.userName)
            await reloadMappingEntries()
            if selectedMappingDatabase == database {
                await MainActor.run { databaseRoleMemberships = [] }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func reloadMappingEntries() async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let name = existingLoginName ?? loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        do {
            let ssec = mssql.serverSecurity
            let mappings = try await ssec.listLoginDatabaseMappings(login: name)
            let mappedSet = Dictionary(uniqueKeysWithValues: mappings.map { ($0.databaseName, $0) })

            await MainActor.run {
                databaseMappings = mappings
                databaseMappingEntries = availableDatabases.map { db in
                    if let mapping = mappedSet[db] {
                        return DatabaseMappingEntry(databaseName: db, isMapped: true, userName: mapping.userName, defaultSchema: mapping.defaultSchema)
                    } else {
                        return DatabaseMappingEntry(databaseName: db, isMapped: false, userName: nil, defaultSchema: nil)
                    }
                }
            }
        } catch { }
    }

    func loadDatabaseRoles(for database: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let entry = databaseMappingEntries.first(where: { $0.databaseName == database })
        guard let userName = entry?.userName, entry?.isMapped == true else {
            await MainActor.run { databaseRoleMemberships = [] }
            return
        }

        await MainActor.run { loadingDatabaseRoles = true }
        do {
            let ssec = mssql.serverSecurity
            let roles = try await ssec.listDatabaseRolesForUser(database: database, userName: userName)
            await MainActor.run {
                databaseRoleMemberships = roles.map { DatabaseRoleMembershipEntry(roleName: $0.roleName, isMember: $0.isMember) }
                loadingDatabaseRoles = false
            }
        } catch {
            await MainActor.run { loadingDatabaseRoles = false }
        }
    }

    func toggleDatabaseRole(database: String, role: String, isMember: Bool) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let entry = databaseMappingEntries.first(where: { $0.databaseName == database })
        guard let userName = entry?.userName else { return }

        do {
            let ssec = mssql.serverSecurity
            if isMember {
                try await ssec.addUserToDatabaseRole(database: database, userName: userName, role: role)
            } else {
                try await ssec.removeUserFromDatabaseRole(database: database, userName: userName, role: role)
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            // Reload to get accurate state
            await loadDatabaseRoles(for: database)
        }
    }

    // MARK: - Submit

    func submit() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return
        }

        let name = loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Login name is required"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            let ssec = mssql.serverSecurity

            if isEditing {
                // Update login properties
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
            } else {
                // Create new login
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

            // Sync server role memberships
            for role in availableServerRoles where role.name != "public" {
                let currentMembers = try await ssec.listServerRoleMembers(role: role.name)
                let isCurrentlyMember = currentMembers.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })

                if role.isMember && !isCurrentlyMember {
                    try await ssec.addMemberToServerRole(role: role.name, principal: name)
                } else if !role.isMember && isCurrentlyMember {
                    try await ssec.removeMemberFromServerRole(role: role.name, principal: name)
                }
            }

            await MainActor.run {
                isSubmitting = false
                onComplete()
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

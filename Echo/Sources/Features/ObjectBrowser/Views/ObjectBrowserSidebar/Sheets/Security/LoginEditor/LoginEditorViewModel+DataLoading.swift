import Foundation
import SQLServerKit

extension LoginEditorViewModel {

    // MARK: - General + Status

    func loadGeneralData(session: ConnectionSession) async {
        isLoadingGeneral = true
        defer { isLoadingGeneral = false }

        guard let mssql = session.session as? MSSQLSession else { return }

        // Load databases
        do {
            let dbs = try await session.session.listDatabases()
            availableDatabases = dbs.sorted()
        } catch { }

        // If editing, load existing login properties
        if let existingName = existingLoginName {
            do {
                let ssec = mssql.serverSecurity
                let logins = try await ssec.listLogins(includeSystemLogins: true)
                if let login = logins.first(where: { $0.name.caseInsensitiveCompare(existingName) == .orderedSame }) {
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
            } catch { }
        }
    }

    // MARK: - Server Roles

    func loadRoles(session: ConnectionSession) async {
        isLoadingRoles = true
        defer {
            isLoadingRoles = false
            hasLoadedRoles = true
        }

        guard let mssql = session.session as? MSSQLSession else { return }

        do {
            let ssec = mssql.serverSecurity
            let roles = try await ssec.listServerRoles()
            var entries = roles.map { role in
                LoginEditorRoleEntry(name: role.name, isFixed: role.isFixed, isMember: false, originallyMember: false)
            }

            if let existingName = existingLoginName {
                for i in entries.indices {
                    let members = try await ssec.listServerRoleMembers(role: entries[i].name)
                    let isMember = members.contains { $0.caseInsensitiveCompare(existingName) == .orderedSame }
                    entries[i] = LoginEditorRoleEntry(
                        name: entries[i].name,
                        isFixed: entries[i].isFixed,
                        isMember: isMember,
                        originallyMember: isMember
                    )
                }

                entries.sort { a, b in
                    if a.isMember != b.isMember { return a.isMember }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            }

            roleEntries = entries
        } catch { }
    }

    // MARK: - User Mapping

    func loadMappings(session: ConnectionSession) async {
        isLoadingMappings = true
        defer {
            isLoadingMappings = false
            hasLoadedMappings = true
        }

        guard let mssql = session.session as? MSSQLSession,
              let existingName = existingLoginName else { return }

        await fetchAndApplyMappings(mssql: mssql, loginName: existingName)
    }

    func reloadMappings(session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession,
              let existingName = existingLoginName else { return }

        await fetchAndApplyMappings(mssql: mssql, loginName: existingName)
    }

    private func fetchAndApplyMappings(mssql: MSSQLSession, loginName: String) async {
        do {
            let mappings = try await mssql.serverSecurity.listLoginDatabaseMappings(login: loginName)
            let mappedSet = Dictionary(
                mappings.map { ($0.databaseName.lowercased(), $0) },
                uniquingKeysWith: { first, _ in first }
            )

            mappingEntries = availableDatabases.map { db in
                if let mapping = mappedSet[db.lowercased()] {
                    LoginEditorMappingEntry(databaseName: db, isMapped: true, userName: mapping.userName, defaultSchema: mapping.defaultSchema)
                } else {
                    LoginEditorMappingEntry(databaseName: db, isMapped: false, userName: nil, defaultSchema: nil)
                }
            }
        } catch { }
    }

    func loadDatabaseRoles(database: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let entry = mappingEntries.first { $0.databaseName == database }
        guard let userName = entry?.userName, entry?.isMapped == true else {
            databaseRoleMemberships = []
            return
        }

        isLoadingDBRoles = true
        do {
            let ssec = mssql.serverSecurity
            let roles = try await ssec.listDatabaseRolesForUser(database: database, userName: userName)
            databaseRoleMemberships = roles.map { LoginEditorDBRoleEntry(roleName: $0.roleName, isMember: $0.isMember) }
            isLoadingDBRoles = false
        } catch {
            isLoadingDBRoles = false
        }
    }

    func mapToDatabase(database: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let name = existingLoginName ?? loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        do {
            try await mssql.serverSecurity.mapLoginToDatabase(login: name, database: database)
        } catch {
            // "already exists" means the mapping is there — not a real error
            let msg = error.localizedDescription
            if !msg.contains("already exists") {
                errorMessage = msg
            }
        }
        // Always reload to reflect actual state
        await reloadMappings(session: session)
    }

    func unmapFromDatabase(database: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let name = existingLoginName ?? loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let entry = mappingEntries.first { $0.databaseName == database }
        do {
            try await mssql.serverSecurity.unmapLoginFromDatabase(login: name, database: database, userName: entry?.userName)
            await reloadMappings(session: session)
            if selectedMappingDatabase == database {
                databaseRoleMemberships = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleDatabaseRole(database: String, role: String, isMember: Bool, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let entry = mappingEntries.first { $0.databaseName == database }
        guard let userName = entry?.userName else { return }

        do {
            let ssec = mssql.serverSecurity
            if isMember {
                try await ssec.addUserToDatabaseRole(database: database, userName: userName, role: role)
            } else {
                try await ssec.removeUserFromDatabaseRole(database: database, userName: userName, role: role)
            }
        } catch {
            errorMessage = error.localizedDescription
            await loadDatabaseRoles(database: database, session: session)
        }
    }

    // MARK: - Securables

    func loadSecurables(session: ConnectionSession) async {
        isLoadingSecurables = true
        defer {
            isLoadingSecurables = false
            hasLoadedSecurables = true
        }

        guard let mssql = session.session as? MSSQLSession,
              let existingName = existingLoginName else { return }

        do {
            let perms = try await mssql.serverSecurity.listPermissions(principal: existingName)
            serverPermissions = perms.map { perm in
                let state = PermissionState(
                    isGranted: perm.state == "GRANT" || perm.state == "GRANT_WITH_GRANT_OPTION",
                    withGrantOption: perm.state == "GRANT_WITH_GRANT_OPTION",
                    isDenied: perm.state == "DENY"
                )
                return LoginEditorPermissionEntry(
                    permission: perm.permission,
                    isGranted: state.isGranted,
                    withGrantOption: state.withGrantOption,
                    isDenied: state.isDenied,
                    originalState: state
                )
            }
        } catch { }
    }
}

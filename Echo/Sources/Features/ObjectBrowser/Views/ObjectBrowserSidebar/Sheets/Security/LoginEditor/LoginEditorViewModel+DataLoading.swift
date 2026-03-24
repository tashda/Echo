import Foundation
import SQLServerKit

extension LoginEditorViewModel {

    // MARK: - General + Status

    func loadGeneralData(session: ConnectionSession) async {
        isLoadingGeneral = true
        defer {
            isLoadingGeneral = false
            takeSnapshot()
        }

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
            takeSnapshot()
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
        } catch { }
    }

    func loadDatabaseRoles(database: String, session: ConnectionSession) async {
        // If we already loaded roles for this DB, just show the cached state
        if databaseRolesPerDB[database] != nil { return }

        guard let mssql = session.session as? MSSQLSession else { return }
        let entry = mappingEntries.first { $0.databaseName == database }
        guard let userName = entry?.userName, entry?.isMapped == true, entry?.originallyMapped == true else {
            // New mapping or unmapped — no server roles to load
            databaseRolesPerDB[database] = defaultDatabaseRoles()
            return
        }

        isLoadingDBRoles = true
        do {
            let ssec = mssql.serverSecurity
            let roles = try await ssec.listDatabaseRolesForUser(database: database, userName: userName)
            databaseRolesPerDB[database] = roles.map {
                LoginEditorDBRoleEntry(roleName: $0.roleName, isMember: $0.isMember, originallyMember: $0.isMember)
            }
            isLoadingDBRoles = false
        } catch {
            databaseRolesPerDB[database] = defaultDatabaseRoles()
            isLoadingDBRoles = false
        }
    }

    /// Default database roles for new mappings (all unchecked).
    private func defaultDatabaseRoles() -> [LoginEditorDBRoleEntry] {
        let standardRoles = [
            "db_accessadmin", "db_backupoperator", "db_datareader", "db_datawriter",
            "db_ddladmin", "db_denydatareader", "db_denydatawriter", "db_owner", "db_securityadmin"
        ]
        return standardRoles.map { LoginEditorDBRoleEntry(roleName: $0, isMember: false, originallyMember: false) }
    }

    // MARK: - Local-Only Mapping Toggles

    func toggleMapping(database: String, isMapped: Bool) {
        guard let idx = mappingEntries.firstIndex(where: { $0.databaseName == database }) else { return }
        mappingEntries[idx].isMapped = isMapped
        if isMapped {
            // Default userName to login name for new mappings
            if mappingEntries[idx].userName == nil {
                mappingEntries[idx].userName = existingLoginName ?? loginName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if mappingEntries[idx].defaultSchema == nil {
                mappingEntries[idx].defaultSchema = "dbo"
            }
            // Ensure roles are available for the inspector
            if databaseRolesPerDB[database] == nil {
                databaseRolesPerDB[database] = defaultDatabaseRoles()
            }
        } else {
            // When unmapping, clear roles but keep them in cache for undo
            if selectedMappingDatabase == database {
                // Roles still visible in inspector but disabled via the "Not Mapped" state
            }
        }
    }

    func toggleDatabaseRoleLocally(database: String, roleName: String, isMember: Bool) {
        guard var roles = databaseRolesPerDB[database],
              let idx = roles.firstIndex(where: { $0.roleName == roleName }) else { return }
        roles[idx] = LoginEditorDBRoleEntry(
            roleName: roles[idx].roleName,
            isMember: isMember,
            originallyMember: roles[idx].originallyMember
        )
        databaseRolesPerDB[database] = roles
    }

    // MARK: - Securables

    func loadSecurables(session: ConnectionSession) async {
        isLoadingSecurables = true
        defer {
            isLoadingSecurables = false
            hasLoadedSecurables = true
        }

        guard let mssql = session.session as? MSSQLSession else { return }

        do {
            // Get all available server permissions
            let allPermissions = try await mssql.serverSecurity.listAllServerPermissions()

            // Get existing grants/denies for this login
            var existingByName: [String: (state: String, grantor: String?)] = [:]
            if let existingName = existingLoginName {
                let existing = try await mssql.serverSecurity.listPermissions(principal: existingName)
                for perm in existing {
                    existingByName[perm.permission] = (state: perm.state, grantor: perm.grantor)
                }
            }

            // Build entries for all permissions, merging existing state
            serverPermissions = allPermissions.map { permName in
                let existing = existingByName[permName]
                let state = PermissionState(
                    isGranted: existing?.state == "GRANT" || existing?.state == "GRANT_WITH_GRANT_OPTION",
                    withGrantOption: existing?.state == "GRANT_WITH_GRANT_OPTION",
                    isDenied: existing?.state == "DENY"
                )
                return LoginEditorPermissionEntry(
                    permission: permName,
                    isGranted: state.isGranted,
                    withGrantOption: state.withGrantOption,
                    isDenied: state.isDenied,
                    originalState: state
                )
            }
            takeSnapshot()
        } catch { }
    }
}

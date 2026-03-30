import Foundation
import SQLServerKit

extension LoginEditorViewModel {

    // MARK: - Eager Loading

    func loadAllData(session: ConnectionSession) async {
        isLoadingGeneral = true
        isLoadingRoles = true
        isLoadingMappings = true
        isLoadingSecurables = true

        guard let mssql = session.session as? MSSQLSession else { return }

        do {
            let data = try await mssql.serverSecurity.getServerLoginEditorData(name: existingLoginName)
            
            self.applyFetchedData(data)
            self.isLoadingGeneral = false
            self.isLoadingRoles = false
            self.isLoadingMappings = false
            self.isLoadingSecurables = false
            self.hasLoadedRoles = true
            self.hasLoadedMappings = true
            self.hasLoadedSecurables = true
            self.takeSnapshot()
        } catch {
            self.isLoadingGeneral = false
            self.isLoadingRoles = false
            self.isLoadingMappings = false
            self.isLoadingSecurables = false
        }
    }

    private func applyFetchedData(_ data: ServerLoginEditorData) {
        self.availableDatabases = data.availableDatabases.sorted()
        
        // 1. General Info
        if let login = data.loginInfo {
            self.loginName = login.name
            self.loginEnabled = !login.isDisabled
            self.defaultDatabase = login.defaultDatabase ?? "master"
            self.defaultLanguage = login.defaultLanguage ?? ""
            self.enforcePasswordPolicy = login.isPolicyChecked ?? true
            self.enforcePasswordExpiration = login.isExpirationChecked ?? false
            switch login.type {
            case .sql: self.authType = .sql
            default: self.authType = .windows
            }
        }

        // 2. Roles
        let memberSet = Set(data.memberOfRoles)
        var roles = data.allServerRoles.map { role in
            let isMember = memberSet.contains(role.name)
            return LoginEditorRoleEntry(
                name: role.name,
                isFixed: role.isFixed,
                isMember: isMember,
                originallyMember: isMember
            )
        }
        roles.sort { a, b in
            if a.isMember != b.isMember { return a.isMember }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        self.roleEntries = roles

        // 3. Mappings
        let mappedSet = Dictionary(
            data.databaseMappings.map { ($0.databaseName.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.mappingEntries = self.availableDatabases.map { db in
            if let mapping = mappedSet[db.lowercased()] {
                return LoginEditorMappingEntry(
                    databaseName: db, isMapped: true, originallyMapped: true,
                    userName: mapping.userName, defaultSchema: mapping.defaultSchema
                )
            } else {
                return LoginEditorMappingEntry(
                    databaseName: db, isMapped: false, originallyMapped: false,
                    userName: nil, defaultSchema: nil
                )
            }
        }

        // 4. Securables (Server Permissions)
        let existingByName = Dictionary(
            data.loginPermissions.map { ($0.permission, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.serverPermissions = data.allServerPermissions.map { permName in
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
    }

    // Keep individual methods for lazy loading fallback, but wrap in MainActor
    
    func loadGeneralData(session: ConnectionSession) async {
        isLoadingGeneral = true
        defer { isLoadingGeneral = false }
        // We reuse the new API even for general-only load if needed, or keep it simple.
        // For simplicity and safety, let's just make it call loadAllData.
        await loadAllData(session: session)
    }

    // MARK: - Server Roles

    func loadRoles(session: ConnectionSession) async {
        await loadAllData(session: session)
    }

    // MARK: - User Mapping

    func loadMappings(session: ConnectionSession) async {
        await loadAllData(session: session)
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
        await loadAllData(session: session)
    }
}

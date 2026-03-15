import SwiftUI
import SQLServerKit

// MARK: - SecurityLoginSheet Data Loading

extension SecurityLoginSheet {

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
}

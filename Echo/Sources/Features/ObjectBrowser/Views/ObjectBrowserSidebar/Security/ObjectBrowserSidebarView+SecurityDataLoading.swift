import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Security Data Loading

extension ObjectBrowserSidebarView {
    // MARK: - Server-Level Security Data Loading

    func loadServerSecurityIfNeeded(session: ConnectionSession) {
        let connID = session.connection.id
        let hasData = !(viewModel.securityLoginsBySession[connID] ?? []).isEmpty
        let isLoading = viewModel.securityServerLoadingBySession[connID] ?? false
        if !hasData && !isLoading {
            loadServerSecurity(session: session)
        }
    }

    func loadServerSecurity(session: ConnectionSession) {
        Task {
            await loadServerSecurityAsync(session: session)
        }
    }

    func loadServerSecurityAsync(session: ConnectionSession) async {
        let connID = session.connection.id
        viewModel.securityServerLoadingBySession[connID] = true

        switch session.connection.databaseType {
        case .microsoftSQL:
            await loadMSSQLServerSecurity(session: session, connID: connID)
        case .postgresql:
            await loadPostgresServerSecurity(session: session, connID: connID)
        default:
            break
        }

        viewModel.securityServerLoadingBySession[connID] = false
    }

    func loadMSSQLServerSecurity(session: ConnectionSession, connID: UUID) async {
        guard let mssql = session.session as? MSSQLSession else { return }

        // Load logins (filter system logins by default)
        do {
            let ssec = mssql.serverSecurity
            let logins = try await ssec.listLogins(includeSystemLogins: false)
            let items = logins.map { login in
                ObjectBrowserSidebarViewModel.SecurityLoginItem(
                    id: login.name,
                    name: login.name,
                    loginType: loginTypeDisplayName(login.type),
                    isDisabled: login.isDisabled
                )
            }
            await MainActor.run { viewModel.securityLoginsBySession[connID] = items }
        } catch {
            await MainActor.run { viewModel.securityLoginsBySession[connID] = [] }
        }

        // Load server roles
        do {
            let ssec = mssql.serverSecurity
            let roles = try await ssec.listServerRoles()
            let items = roles.map { role in
                ObjectBrowserSidebarViewModel.SecurityServerRoleItem(
                    id: role.name,
                    name: role.name,
                    isFixed: role.isFixed
                )
            }
            await MainActor.run { viewModel.securityServerRolesBySession[connID] = items }
        } catch {
            await MainActor.run { viewModel.securityServerRolesBySession[connID] = [] }
        }

        // Load credentials
        do {
            let ssec = mssql.serverSecurity
            let creds = try await ssec.listCredentials()
            let items = creds.map { cred in
                ObjectBrowserSidebarViewModel.SecurityCredentialItem(
                    id: cred.name,
                    name: cred.name,
                    identity: cred.identity ?? ""
                )
            }
            await MainActor.run { viewModel.securityCredentialsBySession[connID] = items }
        } catch {
            await MainActor.run { viewModel.securityCredentialsBySession[connID] = [] }
        }
    }

    func loadPostgresServerSecurity(session: ConnectionSession, connID: UUID) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            let roles = try await pg.client.security.listRoles()

            let items: [ObjectBrowserSidebarViewModel.SecurityLoginItem] = roles.map { role in
                let typeDesc: String
                if role.isSuperuser {
                    typeDesc = "Superuser"
                } else if role.canLogin {
                    typeDesc = "Login Role"
                } else {
                    typeDesc = "Group Role"
                }

                return ObjectBrowserSidebarViewModel.SecurityLoginItem(
                    id: role.name,
                    name: role.name,
                    loginType: typeDesc,
                    isDisabled: false
                )
            }
            await MainActor.run { viewModel.securityLoginsBySession[connID] = items }
        } catch {
            await MainActor.run { viewModel.securityLoginsBySession[connID] = [] }
        }
    }

    // MARK: - Database-Level Security Data Loading

    func loadDatabaseSecurityIfNeeded(database: DatabaseInfo, session: ConnectionSession) {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        let hasData = !(viewModel.dbSecurityUsersByDB[dbKey] ?? []).isEmpty
            || !(viewModel.dbSecuritySchemasByDB[dbKey] ?? []).isEmpty
        let isLoading = viewModel.dbSecurityLoadingByDB[dbKey] ?? false
        if !hasData && !isLoading {
            loadDatabaseSecurity(database: database, session: session)
        }
    }

    func loadDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession) {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        viewModel.dbSecurityLoadingByDB[dbKey] = true

        Task {
            switch session.connection.databaseType {
            case .microsoftSQL:
                await loadMSSQLDatabaseSecurity(database: database, session: session, dbKey: dbKey)
            case .postgresql:
                await loadPostgresDatabaseSecurity(database: database, session: session, dbKey: dbKey)
            default:
                break
            }

            await MainActor.run {
                viewModel.dbSecurityLoadingByDB[dbKey] = false
            }
        }
    }

    func loadMSSQLDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession, dbKey: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let dbName = database.name

        // Switch to target database for the security client
        _ = try? await session.session.sessionForDatabase(dbName)
        let sec = mssql.security

        // Users
        do {
            let users = try await sec.listUsers()
            let items = users
                .filter { $0.name != "sys" && $0.name != "INFORMATION_SCHEMA" }
                .map { u in
                    ObjectBrowserSidebarViewModel.SecurityUserItem(
                        id: u.name,
                        name: u.name,
                        userType: String(describing: u.type),
                        defaultSchema: u.defaultSchema
                    )
                }
            await MainActor.run { viewModel.dbSecurityUsersByDB[dbKey] = items }
        } catch {
            await MainActor.run { viewModel.dbSecurityUsersByDB[dbKey] = [] }
        }

        // Database Roles
        do {
            let roles = try await sec.listRoles()
            let items = roles.map { r in
                ObjectBrowserSidebarViewModel.SecurityDatabaseRoleItem(
                    id: r.name,
                    name: r.name,
                    isFixed: r.isFixedRole,
                    owner: r.ownerPrincipalId.map { String($0) }
                )
            }
            await MainActor.run { viewModel.dbSecurityRolesByDB[dbKey] = items }
        } catch {
            await MainActor.run { viewModel.dbSecurityRolesByDB[dbKey] = [] }
        }

        // Application Roles
        // TODO: Use sec.listApplicationRoles() when made public in sqlserver-nio
        await MainActor.run { viewModel.dbSecurityAppRolesByDB[dbKey] = [] }

        // Schemas
        do {
            let schemas = try await sec.listSchemas()
            let systemSchemas: Set<String> = [
                "sys", "INFORMATION_SCHEMA", "guest",
                "db_owner", "db_accessadmin", "db_securityadmin",
                "db_ddladmin", "db_backupoperator", "db_datareader",
                "db_datawriter", "db_denydatareader", "db_denydatawriter"
            ]
            let items = schemas
                .filter { !systemSchemas.contains($0.name) }
                .map { s in
                    ObjectBrowserSidebarViewModel.SecuritySchemaItem(
                        id: s.name,
                        name: s.name,
                        owner: s.owner
                    )
                }
            await MainActor.run { viewModel.dbSecuritySchemasByDB[dbKey] = items }
        } catch {
            await MainActor.run { viewModel.dbSecuritySchemasByDB[dbKey] = [] }
        }
    }

    func loadPostgresDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession, dbKey: String) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            let schemas = try await pg.client.introspection.listSchemas()

            let items = schemas.map { schema in
                ObjectBrowserSidebarViewModel.SecuritySchemaItem(
                    id: schema.name,
                    name: schema.name,
                    owner: schema.owner
                )
            }
            await MainActor.run { viewModel.dbSecuritySchemasByDB[dbKey] = items }
        } catch {
            await MainActor.run { viewModel.dbSecuritySchemasByDB[dbKey] = [] }
        }
    }
}

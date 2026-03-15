import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Security Actions & Data Loading

extension ObjectBrowserSidebarView {
    // MARK: - Security Folder Context Menu

    @ViewBuilder
    func securityFolderContextMenu(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        switch session.connection.databaseType {
        case .microsoftSQL:
            Button {
                viewModel.securityLoginSheetSessionID = connID
                viewModel.securityLoginSheetEditName = nil
                viewModel.showSecurityLoginSheet = true
            } label: {
                Label("New Login\u{2026}", systemImage: "plus")
            }
        case .postgresql:
            Button {
                viewModel.securityPGRoleSheetSessionID = connID
                viewModel.securityPGRoleSheetEditName = nil
                viewModel.showSecurityPGRoleSheet = true
            } label: {
                Label("New Login Role\u{2026}", systemImage: "plus")
            }
            Button {
                viewModel.securityPGRoleSheetSessionID = connID
                viewModel.securityPGRoleSheetEditName = nil
                viewModel.showSecurityPGRoleSheet = true
            } label: {
                Label("New Group Role\u{2026}", systemImage: "plus")
            }
        default:
            EmptyView()
        }

        Divider()

        Button {
            loadServerSecurity(session: session)
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }

    // MARK: - Shared UI Helpers

    func securitySectionHeader(title: String, icon: String, count: Int?, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        folderHeaderRow(title: title, icon: icon, count: count, isExpanded: isExpanded, action: action)
    }

    func securityLoadingRow(_ text: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)
            ProgressView()
                .controlSize(.mini)
            Text(text)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
    }

    // MARK: - New Item Button

    func newItemButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xs) {
                Spacer().frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: "plus.circle")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(title)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)

                Spacer(minLength: SpacingTokens.xxxs)
            }
            .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Key Helpers

    /// Extracts the database name from a composite key like "UUID#dbName"
    func databaseNameFromKey(_ key: String) -> String {
        if let hashIndex = key.firstIndex(of: "#") {
            return String(key[key.index(after: hashIndex)...])
        }
        return key
    }

    // MARK: - Script Helper

    func openScriptTab(sql: String, session: ConnectionSession) {
        environmentState.openQueryTab(for: session, presetQuery: sql)
    }

    // MARK: - MSSQL Actions

    func dropMSSQLLogin(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.serverSecurity
            try await ssec.dropLogin(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "Login '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    func dropMSSQLUser(name: String, database: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            _ = try? await session.session.simpleQuery("USE [\(database)]")
            let sec = mssql.security
            try await sec.dropUser(name: name)
            // Reload db security
            if let structure = session.databaseStructure,
               let db = structure.databases.first(where: { $0.name == database }) {
                loadDatabaseSecurity(database: db, session: session)
            }
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "User '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    func createMSSQLServerRole(session: ConnectionSession) async {
        // Open a script tab with a CREATE SERVER ROLE template
        openScriptTab(sql: "CREATE SERVER ROLE [NewServerRole];", session: session)
    }

    func dropMSSQLServerRole(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.serverSecurity
            try await ssec.dropServerRole(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "Server role '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    // MARK: - Drop Security Principal Dispatch

    func executeDropSecurityPrincipal(_ target: ObjectBrowserSidebarViewModel.DropSecurityPrincipalTarget, session: ConnectionSession) async {
        switch target.kind {
        case .pgRole:
            await dropPGRole(name: target.name, session: session)
        case .mssqlLogin:
            await dropMSSQLLogin(name: target.name, session: session)
        case .mssqlUser:
            if let db = target.databaseName {
                await dropMSSQLUser(name: target.name, database: db, session: session)
            }
        case .mssqlServerRole:
            await dropMSSQLServerRole(name: target.name, session: session)
        }
    }

    // MARK: - Error Formatting

    func readableErrorMessage(_ error: Error) -> String {
        // PostgresKit's PostgresError already provides good messages via LocalizedError.
        if let pgError = error as? PostgresKit.PostgresError {
            return pgError.message
        }
        // PSQLError now conforms to @retroactive LocalizedError in postgres-wire,
        // so localizedDescription returns the actual server message.
        return error.localizedDescription
    }

    // MARK: - PostgreSQL Actions

    func dropPGRole(name: String, session: ConnectionSession) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            try await pg.client.security.dropUser(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "Role '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    func reassignPGRole(name: String, session: ConnectionSession) async {
        guard session.session is PostgresSession else { return }
        // Open a script tab with a REASSIGN OWNED template
        let sql = """
        -- Reassign all objects owned by "\(name)" to another role.
        -- Replace "target_role" with the role to receive the objects.
        REASSIGN OWNED BY "\(name)" TO "target_role";
        """
        openScriptTab(sql: sql, session: session)
    }

    // MARK: - MSSQL Login Enable/Disable

    func enableMSSQLLogin(name: String, enabled: Bool, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.serverSecurity
            try await ssec.enableLogin(name: name, enabled: enabled)
            loadServerSecurity(session: session)
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityToggleFailed, message: "Failed to \(enabled ? "enable" : "disable") login: \(readableErrorMessage(error))")
            }
        }
    }

    // MARK: - Login Type Display

    func loginTypeDisplayName(_ type: ServerLoginType) -> String {
        switch type {
        case .sql: return "SQL"
        case .windowsUser: return "Windows"
        case .windowsGroup: return "Windows Group"
        case .certificate: return "Certificate"
        case .asymmetricKey: return "Asymmetric Key"
        case .external: return "External"
        }
    }

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
        let connID = session.connection.id
        viewModel.securityServerLoadingBySession[connID] = true

        Task {
            switch session.connection.databaseType {
            case .microsoftSQL:
                await loadMSSQLServerSecurity(session: session, connID: connID)
            case .postgresql:
                await loadPostgresServerSecurity(session: session, connID: connID)
            default:
                break
            }

            await MainActor.run {
                viewModel.securityServerLoadingBySession[connID] = false
            }
        }
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
        _ = try? await session.session.simpleQuery("USE [\(dbName)]")
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

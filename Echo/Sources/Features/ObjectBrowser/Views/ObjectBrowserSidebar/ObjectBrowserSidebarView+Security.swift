import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Server-Level Security Folder

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func securityFolderSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityFolderExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            folderHeaderRow(
                title: "Security",
                icon: "lock.shield",
                count: nil,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityFolderExpandedBySession[connID] = !isExpanded
                }
                if !isExpanded {
                    loadServerSecurityIfNeeded(session: session)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    serverSecurityContent(session: session)
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    @ViewBuilder
    private func serverSecurityContent(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isLoading = viewModel.securityServerLoadingBySession[connID] ?? false
        let hasData = !(viewModel.securityLoginsBySession[connID] ?? []).isEmpty
            || !(viewModel.securityServerRolesBySession[connID] ?? []).isEmpty

        if isLoading && !hasData {
            securityLoadingRow("Loading security\u{2026}")
        }

        switch session.connection.databaseType {
        case .microsoftSQL:
            loginsSection(session: session)
            serverRolesSection(session: session)
            credentialsSection(session: session)
        case .postgresql:
            pgLoginRolesSection(session: session)
            pgGroupRolesSection(session: session)
        default:
            EmptyView()
        }
    }

    // MARK: - MSSQL: Logins

    /// Logins that use certificate or asymmetric key authentication.
    private static let certificateLoginTypes: Set<String> = ["Certificate", "Asymmetric Key"]

    @ViewBuilder
    private func loginsSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let allLogins = viewModel.securityLoginsBySession[connID] ?? []
        let standardLogins = allLogins.filter { !Self.certificateLoginTypes.contains($0.loginType) }
        let certLogins = allLogins.filter { Self.certificateLoginTypes.contains($0.loginType) }
        let isExpanded = viewModel.securityLoginsExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Logins",
                icon: "person.2",
                count: standardLogins.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityLoginsExpandedBySession[connID] = !isExpanded
                }
            }
            .contextMenu {
                Button("New Login\u{2026}") {
                    viewModel.securityLoginSheetSessionID = connID
                    viewModel.securityLoginSheetEditName = nil
                    viewModel.showSecurityLoginSheet = true
                }
                Divider()
                Button("Refresh") {
                    loadServerSecurity(session: session)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(standardLogins) { login in
                        loginRow(login: login, session: session)
                    }

                    // Certificates subfolder
                    if !certLogins.isEmpty {
                        certificateLoginsSubfolder(certLogins: certLogins, session: session)
                    }

                    // New Login button
                    newItemButton(title: "New Login\u{2026}") {
                        viewModel.securityLoginSheetSessionID = connID
                        viewModel.securityLoginSheetEditName = nil
                        viewModel.showSecurityLoginSheet = true
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    @ViewBuilder
    private func certificateLoginsSubfolder(certLogins: [ObjectBrowserSidebarViewModel.SecurityLoginItem], session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityCertLoginsExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Certificate Logins",
                icon: "doc.badge.lock",
                count: certLogins.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityCertLoginsExpandedBySession[connID] = !isExpanded
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(certLogins) { login in
                        loginRow(login: login, session: session)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func loginRow(login: ObjectBrowserSidebarViewModel.SecurityLoginItem, session: ConnectionSession) -> some View {
        HStack(spacing: 8) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: login.isDisabled ? "person.crop.circle.badge.xmark" : "person.crop.circle")
                .font(.system(size: 12))
                .foregroundStyle(login.isDisabled ? .tertiary : .secondary)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(login.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(login.isDisabled ? .secondary : .primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(login.loginType)
                .font(TypographyTokens.label)
                .foregroundStyle(.tertiary)

            if login.isDisabled {
                Text("Disabled")
                    .font(TypographyTokens.label)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Properties\u{2026}") {
                viewModel.securityLoginSheetSessionID = session.connection.id
                viewModel.securityLoginSheetEditName = login.name
                viewModel.showSecurityLoginSheet = true
            }
            Divider()
            Button("Script as CREATE") {
                let sql: String
                if login.loginType == "SQL" {
                    sql = "CREATE LOGIN [\(login.name)] WITH PASSWORD = N'<password>';"
                } else {
                    sql = "CREATE LOGIN [\(login.name)] FROM WINDOWS;"
                }
                openScriptTab(sql: sql, session: session)
            }
            Button("Script as DROP") {
                openScriptTab(sql: "DROP LOGIN [\(login.name)];", session: session)
            }
            Divider()
            if login.isDisabled {
                Button("Enable Login") {
                    Task { await enableMSSQLLogin(name: login.name, enabled: true, session: session) }
                }
            } else {
                Button("Disable Login") {
                    Task { await enableMSSQLLogin(name: login.name, enabled: false, session: session) }
                }
            }
            Divider()
            Button("Drop Login", role: .destructive) {
                Task { await dropMSSQLLogin(name: login.name, session: session) }
            }
        }
    }

    // MARK: - MSSQL: Server Roles

    @ViewBuilder
    private func serverRolesSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let roles = viewModel.securityServerRolesBySession[connID] ?? []
        let isExpanded = viewModel.securityServerRolesExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Server Roles",
                icon: "shield.lefthalf.filled",
                count: roles.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityServerRolesExpandedBySession[connID] = !isExpanded
                }
            }
            .contextMenu {
                Button("New Server Role\u{2026}") {
                    Task { await createMSSQLServerRole(session: session) }
                }
                Divider()
                Button("Refresh") {
                    loadServerSecurity(session: session)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(roles) { role in
                        serverRoleRow(role: role, session: session)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func serverRoleRow(role: ObjectBrowserSidebarViewModel.SecurityServerRoleItem, session: ConnectionSession) -> some View {
        HStack(spacing: 8) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: role.isFixed ? "shield.lefthalf.filled" : "shield")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(role.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if role.isFixed {
                Text("Fixed")
                    .font(TypographyTokens.label)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            if !role.isFixed {
                Button("Script as CREATE") {
                    openScriptTab(sql: "CREATE SERVER ROLE [\(role.name)];", session: session)
                }
                Button("Script as DROP") {
                    openScriptTab(sql: "DROP SERVER ROLE [\(role.name)];", session: session)
                }
                Divider()
                Button("Drop Server Role", role: .destructive) {
                    Task { await dropMSSQLServerRole(name: role.name, session: session) }
                }
                Divider()
            }
            Button("List Members") {
                openScriptTab(
                    sql: """
                    SELECT m.name AS member_name, m.type_desc
                    FROM sys.server_role_members rm
                    JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
                    JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
                    WHERE r.name = N'\(role.name)';
                    """,
                    session: session
                )
            }
        }
    }

    // MARK: - MSSQL: Credentials

    @ViewBuilder
    private func credentialsSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let credentials = viewModel.securityCredentialsBySession[connID] ?? []
        let isExpanded = viewModel.securityCredentialsExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Credentials",
                icon: "key",
                count: credentials.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityCredentialsExpandedBySession[connID] = !isExpanded
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    if credentials.isEmpty {
                        HStack(spacing: 8) {
                            Spacer().frame(width: SidebarRowConstants.chevronWidth)
                            Text("No credentials found")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
                        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                    } else {
                        ForEach(credentials) { credential in
                            credentialRow(credential: credential, session: session)
                        }
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func credentialRow(credential: ObjectBrowserSidebarViewModel.SecurityCredentialItem, session: ConnectionSession) -> some View {
        HStack(spacing: 8) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: "key")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(credential.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(credential.identity)
                .font(TypographyTokens.label)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Script as CREATE") {
                openScriptTab(
                    sql: "CREATE CREDENTIAL [\(credential.name)] WITH IDENTITY = N'\(credential.identity)', SECRET = N'<secret>';",
                    session: session
                )
            }
            Button("Script as DROP") {
                openScriptTab(sql: "DROP CREDENTIAL [\(credential.name)];", session: session)
            }
        }
    }

    // MARK: - PostgreSQL: Login Roles (separate folder)

    @ViewBuilder
    private func pgLoginRolesSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let allRoles = viewModel.securityLoginsBySession[connID] ?? []
        let loginRoles = allRoles.filter { $0.loginType.contains("Login") || $0.loginType.contains("Superuser") }
        let isExpanded = viewModel.securityPGLoginRolesExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Login Roles",
                icon: "person.crop.circle",
                count: loginRoles.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityPGLoginRolesExpandedBySession[connID] = !isExpanded
                }
            }
            .contextMenu {
                Button("New Login Role\u{2026}") {
                    viewModel.securityPGRoleSheetSessionID = connID
                    viewModel.securityPGRoleSheetEditName = nil
                    viewModel.showSecurityPGRoleSheet = true
                }
                Divider()
                Button("Refresh") {
                    loadServerSecurity(session: session)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(loginRoles) { role in
                        pgRoleRow(role: role, session: session)
                    }

                    newItemButton(title: "New Login Role\u{2026}") {
                        viewModel.securityPGRoleSheetSessionID = connID
                        viewModel.securityPGRoleSheetEditName = nil
                        viewModel.showSecurityPGRoleSheet = true
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    // MARK: - PostgreSQL: Group Roles (separate folder)

    @ViewBuilder
    private func pgGroupRolesSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let allRoles = viewModel.securityLoginsBySession[connID] ?? []
        let groupRoles = allRoles.filter { $0.loginType == "Group Role" }
        let isExpanded = viewModel.securityPGGroupRolesExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Group Roles",
                icon: "person.2.circle",
                count: groupRoles.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityPGGroupRolesExpandedBySession[connID] = !isExpanded
                }
            }
            .contextMenu {
                Button("New Group Role\u{2026}") {
                    viewModel.securityPGRoleSheetSessionID = connID
                    viewModel.securityPGRoleSheetEditName = nil
                    viewModel.showSecurityPGRoleSheet = true
                }
                Divider()
                Button("Refresh") {
                    loadServerSecurity(session: session)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groupRoles) { role in
                        pgRoleRow(role: role, session: session)
                    }

                    newItemButton(title: "New Group Role\u{2026}") {
                        viewModel.securityPGRoleSheetSessionID = connID
                        viewModel.securityPGRoleSheetEditName = nil
                        viewModel.showSecurityPGRoleSheet = true
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func pgRoleRow(role: ObjectBrowserSidebarViewModel.SecurityLoginItem, session: ConnectionSession) -> some View {
        HStack(spacing: 8) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: role.loginType.contains("Login") || role.loginType.contains("Superuser") ? "person.crop.circle" : "person.2.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(role.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(role.loginType)
                .font(TypographyTokens.label)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Properties\u{2026}") {
                viewModel.securityPGRoleSheetSessionID = session.connection.id
                viewModel.securityPGRoleSheetEditName = role.name
                viewModel.showSecurityPGRoleSheet = true
            }
            Divider()
            Button("Script as CREATE") {
                let loginAttr = role.loginType.contains("Login") || role.loginType.contains("Superuser") ? " LOGIN" : ""
                openScriptTab(sql: "CREATE ROLE \"\(role.name)\"\(loginAttr);", session: session)
            }
            Button("Script as DROP") {
                openScriptTab(sql: "DROP ROLE \"\(role.name)\";", session: session)
            }
            Divider()
            Button("Reassign Owned Objects\u{2026}") {
                Task { await reassignPGRole(name: role.name, session: session) }
            }
            Button("Drop Role", role: .destructive) {
                Task { await dropPGRole(name: role.name, session: session) }
            }
        }
    }

    // MARK: - Database-Level Security Section

    @ViewBuilder
    func databaseSecuritySection(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        let isExpanded = viewModel.dbSecurityExpandedByDB[dbKey] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Security",
                icon: "lock.shield",
                count: nil,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.dbSecurityExpandedByDB[dbKey] = !isExpanded
                }
                if !isExpanded {
                    loadDatabaseSecurityIfNeeded(database: database, session: session)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    databaseSecurityContent(database: database, session: session, dbKey: dbKey)
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    @ViewBuilder
    private func databaseSecurityContent(database: DatabaseInfo, session: ConnectionSession, dbKey: String) -> some View {
        let isLoading = viewModel.dbSecurityLoadingByDB[dbKey] ?? false
        let hasData = !(viewModel.dbSecurityUsersByDB[dbKey] ?? []).isEmpty
            || !(viewModel.dbSecuritySchemasByDB[dbKey] ?? []).isEmpty

        if isLoading && !hasData {
            securityLoadingRow("Loading security\u{2026}")
        }

        switch session.connection.databaseType {
        case .microsoftSQL:
            dbUsersSection(session: session, dbKey: dbKey)
            dbRolesSection(session: session, dbKey: dbKey)
            dbAppRolesSection(session: session, dbKey: dbKey)
            dbSchemasSection(session: session, dbKey: dbKey)
        case .postgresql:
            dbSchemasSection(session: session, dbKey: dbKey)
        default:
            EmptyView()
        }
    }

    // MARK: - Database Users (MSSQL)

    @ViewBuilder
    private func dbUsersSection(session: ConnectionSession, dbKey: String) -> some View {
        let connID = session.connection.id
        let users = viewModel.dbSecurityUsersByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecurityUsersExpandedByDB[dbKey] ?? false
        let dbName = databaseNameFromKey(dbKey)

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Users",
                icon: "person.fill",
                count: users.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.dbSecurityUsersExpandedByDB[dbKey] = !isExpanded
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(users) { user in
                        dbUserRow(user: user, session: session, databaseName: dbName)
                    }

                    newItemButton(title: "New User\u{2026}") {
                        viewModel.securityUserSheetSessionID = connID
                        viewModel.securityUserSheetDatabaseName = dbName
                        viewModel.securityUserSheetEditName = nil
                        viewModel.showSecurityUserSheet = true
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func dbUserRow(user: ObjectBrowserSidebarViewModel.SecurityUserItem, session: ConnectionSession, databaseName: String) -> some View {
        HStack(spacing: 8) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: "person.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(user.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let schema = user.defaultSchema, !schema.isEmpty {
                Text(schema)
                    .font(TypographyTokens.label)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Properties\u{2026}") {
                viewModel.securityUserSheetSessionID = session.connection.id
                viewModel.securityUserSheetDatabaseName = databaseName
                viewModel.securityUserSheetEditName = user.name
                viewModel.showSecurityUserSheet = true
            }
            Divider()
            Button("Script as CREATE") {
                openScriptTab(
                    sql: "CREATE USER [\(user.name)] FOR LOGIN [\(user.name)]\(user.defaultSchema.map { " WITH DEFAULT_SCHEMA = [\($0)]" } ?? "");",
                    session: session
                )
            }
            Button("Script as DROP") {
                openScriptTab(sql: "DROP USER [\(user.name)];", session: session)
            }
            Divider()
            Button("Drop User", role: .destructive) {
                Task { await dropMSSQLUser(name: user.name, database: databaseName, session: session) }
            }
            Divider()
            Button("List Role Memberships") {
                openScriptTab(
                    sql: """
                    SELECT dp.name AS role_name
                    FROM sys.database_role_members rm
                    JOIN sys.database_principals dp ON rm.role_principal_id = dp.principal_id
                    JOIN sys.database_principals mp ON rm.member_principal_id = mp.principal_id
                    WHERE mp.name = N'\(user.name)';
                    """,
                    session: session
                )
            }
            Button("Show Permissions") {
                openScriptTab(
                    sql: """
                    SELECT perm.state_desc, perm.permission_name,
                           OBJECT_SCHEMA_NAME(perm.major_id) AS schema_name,
                           OBJECT_NAME(perm.major_id) AS object_name,
                           perm.class_desc
                    FROM sys.database_permissions perm
                    JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
                    WHERE dp.name = N'\(user.name)'
                    ORDER BY perm.class_desc, object_name, perm.permission_name;
                    """,
                    session: session
                )
            }
        }
    }

    // MARK: - Database Roles (MSSQL)

    @ViewBuilder
    private func dbRolesSection(session: ConnectionSession, dbKey: String) -> some View {
        let roles = viewModel.dbSecurityRolesByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecurityRolesExpandedByDB[dbKey] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Database Roles",
                icon: "shield.lefthalf.filled",
                count: roles.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.dbSecurityRolesExpandedByDB[dbKey] = !isExpanded
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(roles) { role in
                        dbRoleRow(role: role, session: session)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func dbRoleRow(role: ObjectBrowserSidebarViewModel.SecurityDatabaseRoleItem, session: ConnectionSession) -> some View {
        HStack(spacing: 8) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: role.isFixed ? "shield.lefthalf.filled" : "shield")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(role.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if role.isFixed {
                Text("Fixed")
                    .font(TypographyTokens.label)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            if !role.isFixed {
                Button("Script as CREATE") {
                    openScriptTab(sql: "CREATE ROLE [\(role.name)];", session: session)
                }
                Button("Script as DROP") {
                    openScriptTab(sql: "DROP ROLE [\(role.name)];", session: session)
                }
                Divider()
            }
            Button("List Members") {
                openScriptTab(
                    sql: """
                    SELECT mp.name AS member_name, mp.type_desc
                    FROM sys.database_role_members rm
                    JOIN sys.database_principals rp ON rm.role_principal_id = rp.principal_id
                    JOIN sys.database_principals mp ON rm.member_principal_id = mp.principal_id
                    WHERE rp.name = N'\(role.name)';
                    """,
                    session: session
                )
            }
        }
    }

    // MARK: - Application Roles (MSSQL)

    @ViewBuilder
    private func dbAppRolesSection(session: ConnectionSession, dbKey: String) -> some View {
        let appRoles = viewModel.dbSecurityAppRolesByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecurityAppRolesExpandedByDB[dbKey] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Application Roles",
                icon: "app.badge",
                count: appRoles.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.dbSecurityAppRolesExpandedByDB[dbKey] = !isExpanded
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(appRoles) { appRole in
                        dbAppRoleRow(appRole: appRole, session: session)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func dbAppRoleRow(appRole: ObjectBrowserSidebarViewModel.SecurityAppRoleItem, session: ConnectionSession) -> some View {
        HStack(spacing: 8) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: "app.badge")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(appRole.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let schema = appRole.defaultSchema, !schema.isEmpty {
                Text(schema)
                    .font(TypographyTokens.label)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Script as CREATE") {
                openScriptTab(
                    sql: "CREATE APPLICATION ROLE [\(appRole.name)] WITH PASSWORD = N'<password>'\(appRole.defaultSchema.map { ", DEFAULT_SCHEMA = [\($0)]" } ?? "");",
                    session: session
                )
            }
            Button("Script as DROP") {
                openScriptTab(sql: "DROP APPLICATION ROLE [\(appRole.name)];", session: session)
            }
        }
    }

    // MARK: - Database Schemas

    @ViewBuilder
    private func dbSchemasSection(session: ConnectionSession, dbKey: String) -> some View {
        let schemas = viewModel.dbSecuritySchemasByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecuritySchemasExpandedByDB[dbKey] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Schemas",
                icon: "folder",
                count: schemas.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.dbSecuritySchemasExpandedByDB[dbKey] = !isExpanded
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(schemas) { schema in
                        dbSchemaRow(schema: schema, session: session)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func dbSchemaRow(schema: ObjectBrowserSidebarViewModel.SecuritySchemaItem, session: ConnectionSession) -> some View {
        HStack(spacing: 8) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(schema.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let owner = schema.owner, !owner.isEmpty {
                Text(owner)
                    .font(TypographyTokens.label)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            if session.connection.databaseType == .microsoftSQL {
                Button("Script as CREATE") {
                    let auth = schema.owner.map { " AUTHORIZATION [\($0)]" } ?? ""
                    openScriptTab(sql: "CREATE SCHEMA [\(schema.name)]\(auth);", session: session)
                }
                Button("Script as DROP") {
                    openScriptTab(sql: "DROP SCHEMA [\(schema.name)];", session: session)
                }
            } else if session.connection.databaseType == .postgresql {
                Button("Script as CREATE") {
                    let auth = schema.owner.map { " AUTHORIZATION \"\($0)\"" } ?? ""
                    openScriptTab(sql: "CREATE SCHEMA \"\(schema.name)\"\(auth);", session: session)
                }
                Button("Script as DROP") {
                    openScriptTab(sql: "DROP SCHEMA \"\(schema.name)\" CASCADE;", session: session)
                }
            }
            Divider()
            Button("Show Privileges") {
                if session.connection.databaseType == .microsoftSQL {
                    openScriptTab(
                        sql: """
                        SELECT perm.state_desc, perm.permission_name, dp.name AS grantee
                        FROM sys.database_permissions perm
                        JOIN sys.schemas s ON perm.major_id = s.schema_id
                        JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
                        WHERE s.name = N'\(schema.name)' AND perm.class = 3
                        ORDER BY dp.name, perm.permission_name;
                        """,
                        session: session
                    )
                } else {
                    openScriptTab(
                        sql: """
                        SELECT grantee, privilege_type, is_grantable
                        FROM information_schema.usage_privileges
                        WHERE object_schema = '\(schema.name)'
                        UNION ALL
                        SELECT grantee, privilege_type, is_grantable
                        FROM information_schema.role_table_grants
                        WHERE table_schema = '\(schema.name)'
                        ORDER BY 1, 2;
                        """,
                        session: session
                    )
                }
            }
        }
    }

    // MARK: - Shared UI Helpers

    func securitySectionHeader(title: String, icon: String, count: Int?, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(SidebarRowConstants.chevronFont)
                    .foregroundStyle(.tertiary)
                    .frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(title)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(TypographyTokens.label)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func securityLoadingRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)
            ProgressView()
                .controlSize(.mini)
            Text(text)
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
    }

    // MARK: - New Item Button

    func newItemButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Spacer().frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(title)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Key Helpers

    /// Extracts the database name from a composite key like "UUID#dbName"
    private func databaseNameFromKey(_ key: String) -> String {
        if let hashIndex = key.firstIndex(of: "#") {
            return String(key[key.index(after: hashIndex)...])
        }
        return key
    }

    // MARK: - Script Helper

    private func openScriptTab(sql: String, session: ConnectionSession) {
        environmentState.openQueryTab(for: session, presetQuery: sql)
    }

    // MARK: - MSSQL Actions

    private func dropMSSQLLogin(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.makeServerSecurityClient()
            try await ssec.dropLogin(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "checkmark.circle", message: "Login '\(name)' dropped", style: .success)
            }
        } catch {
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: "Drop failed: \(error.localizedDescription)", style: .error)
            }
        }
    }

    private func dropMSSQLUser(name: String, database: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            _ = try? await session.session.simpleQuery("USE [\(database)]")
            let sec = mssql.makeDatabaseSecurityClient()
            try await sec.dropUser(name: name)
            // Reload db security
            if let structure = session.databaseStructure,
               let db = structure.databases.first(where: { $0.name == database }) {
                loadDatabaseSecurity(database: db, session: session)
            }
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "checkmark.circle", message: "User '\(name)' dropped", style: .success)
            }
        } catch {
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: "Drop failed: \(error.localizedDescription)", style: .error)
            }
        }
    }

    private func createMSSQLServerRole(session: ConnectionSession) async {
        // Open a script tab with a CREATE SERVER ROLE template
        openScriptTab(sql: "CREATE SERVER ROLE [NewServerRole];", session: session)
    }

    private func dropMSSQLServerRole(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.makeServerSecurityClient()
            try await ssec.dropServerRole(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "checkmark.circle", message: "Server role '\(name)' dropped", style: .success)
            }
        } catch {
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: "Drop failed: \(error.localizedDescription)", style: .error)
            }
        }
    }

    // MARK: - PostgreSQL Actions

    private func dropPGRole(name: String, session: ConnectionSession) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            try await pg.client.dropUser(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "checkmark.circle", message: "Role '\(name)' dropped", style: .success)
            }
        } catch {
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: "Drop failed: \(error.localizedDescription)", style: .error)
            }
        }
    }

    private func reassignPGRole(name: String, session: ConnectionSession) async {
        guard let pg = session.session as? PostgresSession else { return }
        // Open a script tab with a REASSIGN OWNED template
        let sql = """
        -- Reassign all objects owned by "\(name)" to another role.
        -- Replace "target_role" with the role to receive the objects.
        REASSIGN OWNED BY "\(name)" TO "target_role";
        """
        openScriptTab(sql: sql, session: session)
    }

    // MARK: - MSSQL Login Enable/Disable

    private func enableMSSQLLogin(name: String, enabled: Bool, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.makeServerSecurityClient()
            try await ssec.enableLogin(name: name, enabled: enabled)
            loadServerSecurity(session: session)
        } catch {
            await MainActor.run {
                environmentState.toastCoordinator.show(
                    icon: "exclamationmark.triangle",
                    message: "Failed to \(enabled ? "enable" : "disable") login: \(error.localizedDescription)",
                    style: .error
                )
            }
        }
    }

    // MARK: - Login Type Display

    private func loginTypeDisplayName(_ type: ServerLoginType) -> String {
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

    private func loadMSSQLServerSecurity(session: ConnectionSession, connID: UUID) async {
        guard let mssql = session.session as? MSSQLSession else { return }

        // Load logins (filter system logins by default)
        do {
            let ssec = mssql.makeServerSecurityClient()
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
            let ssec = mssql.makeServerSecurityClient()
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
            let ssec = mssql.makeServerSecurityClient()
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

    private func loadPostgresServerSecurity(session: ConnectionSession, connID: UUID) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            let admin = PostgresAdmin(client: pg.client, logger: pg.logger)
            let roles = try await admin.listRoles()

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

    private func loadMSSQLDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession, dbKey: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let dbName = database.name

        // Switch to target database for the security client
        _ = try? await session.session.simpleQuery("USE [\(dbName)]")
        let sec = mssql.makeDatabaseSecurityClient()

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
        do {
            let appRoles = try await sec.listApplicationRoles().get()
            let items = appRoles.map { ar in
                ObjectBrowserSidebarViewModel.SecurityAppRoleItem(
                    id: ar.name,
                    name: ar.name,
                    defaultSchema: ar.defaultSchema
                )
            }
            await MainActor.run { viewModel.dbSecurityAppRolesByDB[dbKey] = items }
        } catch {
            await MainActor.run { viewModel.dbSecurityAppRolesByDB[dbKey] = [] }
        }

        // Schemas
        do {
            let schemas = try await sec.listSchemas().get()
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

    private func loadPostgresDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession, dbKey: String) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            let admin = PostgresAdmin(client: pg.client, logger: pg.logger)
            let schemas = try await admin.listSchemas()

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

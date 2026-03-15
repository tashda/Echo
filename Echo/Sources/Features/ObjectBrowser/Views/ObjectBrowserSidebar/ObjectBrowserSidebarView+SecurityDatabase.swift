import SwiftUI
import SQLServerKit

// MARK: - Database-Level Security

extension ObjectBrowserSidebarView {
    // MARK: - Database-Level Security Section

    @ViewBuilder
    func databaseSecuritySection(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        let isExpanded = viewModel.dbSecurityExpandedByDB[dbKey] ?? false

        VStack(alignment: .leading, spacing: 0) {
            folderHeaderRow(
                title: "Security",
                icon: "shield.fill",
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
    func databaseSecurityContent(database: DatabaseInfo, session: ConnectionSession, dbKey: String) -> some View {
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
    func dbUsersSection(session: ConnectionSession, dbKey: String) -> some View {
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

    func dbUserRow(user: ObjectBrowserSidebarViewModel.SecurityUserItem, session: ConnectionSession, databaseName: String) -> some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: "person.fill")
                .font(SidebarRowConstants.iconFont)
                .foregroundStyle(ExplorerSidebarPalette.security)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(user.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)

            Spacer(minLength: SpacingTokens.xxxs)

            if let schema = user.defaultSchema, !schema.isEmpty {
                Text(schema)
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
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
            } label: {
                Label("List Role Memberships", systemImage: "person.2")
            }
            Button {
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
            } label: {
                Label("Show Permissions", systemImage: "lock.shield")
            }
            Divider()
            Button(role: .destructive) {
                viewModel.dropSecurityPrincipalTarget = .init(
                    sessionID: session.id,
                    connectionID: session.connection.id,
                    name: user.name,
                    kind: .mssqlUser,
                    databaseName: databaseName
                )
                viewModel.showDropSecurityPrincipalAlert = true
            } label: {
                Label("Drop User", systemImage: "trash")
            }
            Divider()
            Menu {
                Button("CREATE") {
                    openScriptTab(
                        sql: "CREATE USER [\(user.name)] FOR LOGIN [\(user.name)]\(user.defaultSchema.map { " WITH DEFAULT_SCHEMA = [\($0)]" } ?? "");",
                        session: session
                    )
                }
                Button("DROP") {
                    openScriptTab(sql: "DROP USER [\(user.name)];", session: session)
                }
            } label: {
                Label("Script as", systemImage: "scroll")
            }
            Divider()
            Button {
                viewModel.securityUserSheetSessionID = session.connection.id
                viewModel.securityUserSheetDatabaseName = databaseName
                viewModel.securityUserSheetEditName = user.name
                viewModel.showSecurityUserSheet = true
            } label: {
                Label("Properties\u{2026}", systemImage: "info.circle")
            }
        }
    }

    // MARK: - Database Roles (MSSQL)

    @ViewBuilder
    func dbRolesSection(session: ConnectionSession, dbKey: String) -> some View {
        let roles = viewModel.dbSecurityRolesByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecurityRolesExpandedByDB[dbKey] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                title: "Database Roles",
                icon: "shield.fill",
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

    func dbRoleRow(role: ObjectBrowserSidebarViewModel.SecurityDatabaseRoleItem, session: ConnectionSession) -> some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: role.isFixed ? "shield.lefthalf.filled" : "shield")
                .font(SidebarRowConstants.iconFont)
                .foregroundStyle(ExplorerSidebarPalette.security)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(role.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)

            Spacer(minLength: SpacingTokens.xxxs)

            if role.isFixed {
                Text("Fixed")
                    .font(TypographyTokens.label)
                    .foregroundStyle(ColorTokens.Text.quaternary)
            }
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
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
            } label: {
                Label("List Members", systemImage: "person.2")
            }
            if !role.isFixed {
                Divider()
                Menu {
                    Button("CREATE") {
                        openScriptTab(sql: "CREATE ROLE [\(role.name)];", session: session)
                    }
                    Button("DROP") {
                        openScriptTab(sql: "DROP ROLE [\(role.name)];", session: session)
                    }
                } label: {
                    Label("Script as", systemImage: "scroll")
                }
            }
        }
    }

    // MARK: - Application Roles (MSSQL)

    @ViewBuilder
    func dbAppRolesSection(session: ConnectionSession, dbKey: String) -> some View {
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

    func dbAppRoleRow(appRole: ObjectBrowserSidebarViewModel.SecurityAppRoleItem, session: ConnectionSession) -> some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: "app.badge")
                .font(SidebarRowConstants.iconFont)
                .foregroundStyle(ExplorerSidebarPalette.security)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(appRole.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)

            Spacer(minLength: SpacingTokens.xxxs)

            if let schema = appRole.defaultSchema, !schema.isEmpty {
                Text(schema)
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Menu {
                Button("CREATE") {
                    openScriptTab(
                        sql: "CREATE APPLICATION ROLE [\(appRole.name)] WITH PASSWORD = N'<password>'\(appRole.defaultSchema.map { ", DEFAULT_SCHEMA = [\($0)]" } ?? "");",
                        session: session
                    )
                }
                Button("DROP") {
                    openScriptTab(sql: "DROP APPLICATION ROLE [\(appRole.name)];", session: session)
                }
            } label: {
                Label("Script as", systemImage: "scroll")
            }
        }
    }

    // MARK: - Database Schemas

    @ViewBuilder
    func dbSchemasSection(session: ConnectionSession, dbKey: String) -> some View {
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

    func dbSchemaRow(schema: ObjectBrowserSidebarViewModel.SecuritySchemaItem, session: ConnectionSession) -> some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: "folder")
                .font(SidebarRowConstants.iconFont)
                .foregroundStyle(ExplorerSidebarPalette.security)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(schema.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)

            Spacer(minLength: SpacingTokens.xxxs)

            if let owner = schema.owner, !owner.isEmpty {
                Text(owner)
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
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
            } label: {
                Label("Show Privileges", systemImage: "lock.shield")
            }
            Divider()
            Menu {
                if session.connection.databaseType == .microsoftSQL {
                    Button("CREATE") {
                        let auth = schema.owner.map { " AUTHORIZATION [\($0)]" } ?? ""
                        openScriptTab(sql: "CREATE SCHEMA [\(schema.name)]\(auth);", session: session)
                    }
                    Button("DROP") {
                        openScriptTab(sql: "DROP SCHEMA [\(schema.name)];", session: session)
                    }
                } else if session.connection.databaseType == .postgresql {
                    Button("CREATE") {
                        let auth = schema.owner.map { " AUTHORIZATION \"\($0)\"" } ?? ""
                        openScriptTab(sql: "CREATE SCHEMA \"\(schema.name)\"\(auth);", session: session)
                    }
                    Button("DROP") {
                        openScriptTab(sql: "DROP SCHEMA \"\(schema.name)\" CASCADE;", session: session)
                    }
                }
            } label: {
                Label("Script as", systemImage: "scroll")
            }
        }
    }

}

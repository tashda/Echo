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
}

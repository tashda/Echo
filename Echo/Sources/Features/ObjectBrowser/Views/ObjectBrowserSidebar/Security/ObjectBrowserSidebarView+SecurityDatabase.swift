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
        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { newValue in
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                    viewModel.dbSecurityExpandedByDB[dbKey] = newValue
                }
                if newValue {
                    loadDatabaseSecurityIfNeeded(database: database, session: session)
                }
            }
        )

        Button {
            expandedBinding.wrappedValue.toggle()
        } label: {
            SidebarRow(
                depth: SecuritySidebarDepth.serverNestedSection,
                icon: .system("shield"),
                label: "Security",
                isExpanded: expandedBinding,
                iconColor: ExplorerSidebarPalette.folderIconColor(title: "Security", colored: projectStore.globalSettings.sidebarIconColorMode == .colorful)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button {
                let dbName = databaseNameFromKey(dbKey)
                environmentState.openDatabaseSecurityTab(connectionID: session.connection.id, databaseName: dbName)
            } label: {
                Label("Open Security Management", systemImage: "lock.shield")
            }
        }

        if isExpanded {
            databaseSecurityContent(database: database, session: session, dbKey: dbKey)
        }
    }

    @ViewBuilder
    func databaseSecurityContent(database: DatabaseInfo, session: ConnectionSession, dbKey: String) -> some View {
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
        let users = viewModel.dbSecurityUsersByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecurityUsersExpandedByDB[dbKey] ?? false
        let dbName = databaseNameFromKey(dbKey)

        securitySectionHeader(
            depth: SecuritySidebarDepth.databaseSection,
            title: "Users",
            icon: "person",
            count: users.count,
            isExpanded: Binding<Bool>(
                get: { isExpanded },
                set: { newValue in viewModel.dbSecurityUsersExpandedByDB[dbKey] = newValue }
            )
        )

        if isExpanded {
            if users.isEmpty {
                SidebarRow(
                    depth: SecuritySidebarDepth.databaseLeaf,
                    icon: .none,
                    label: "No users found",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                )
            } else {
                ForEach(users) { user in
                    dbUserRow(user: user, session: session, databaseName: dbName)
                }
            }
        }
    }

    func dbUserRow(user: ObjectBrowserSidebarViewModel.SecurityUserItem, session: ConnectionSession, databaseName: String) -> some View {
        let isColorful = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return SidebarRow(
            depth: SecuritySidebarDepth.databaseLeaf,
            icon: .system("person"),
            label: user.name,
            iconColor: ExplorerSidebarPalette.folderIconColor(title: "Users", colored: isColorful)
        ) {
            if let schema = user.defaultSchema, !schema.isEmpty {
                Text(schema)
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            // Group 3: Open / View
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

            // Group 6: Script as
            Menu("Script as", systemImage: "scroll") {
                Button {
                    openScriptTab(
                        sql: "CREATE USER [\(user.name)] FOR LOGIN [\(user.name)]\(user.defaultSchema.map { " WITH DEFAULT_SCHEMA = [\($0)]" } ?? "");",
                        session: session
                    )
                } label: {
                    Label("CREATE", systemImage: "plus.rectangle.on.rectangle")
                }
                Divider()
                Button {
                    openScriptTab(sql: "DROP USER [\(user.name)];", session: session)
                } label: {
                    Label("DROP", systemImage: "trash")
                }
            }

            Divider()

            // Group 9: Destructive
            Button(role: .destructive) {
                sheetState.dropSecurityPrincipalTarget = .init(
                    sessionID: session.id,
                    connectionID: session.connection.id,
                    name: user.name,
                    kind: .mssqlUser,
                    databaseName: databaseName
                )
                sheetState.showDropSecurityPrincipalAlert = true
            } label: {
                Label("Drop User", systemImage: "trash")
            }
            .disabled(!(session.permissions?.canManageRoles ?? true))

            Divider()

            // Group 10: Properties — ALWAYS last
            Button {
                let value = environmentState.prepareUserEditorWindow(
                    connectionSessionID: session.connection.id,
                    database: databaseName,
                    existingUser: user.name
                )
                openWindow(id: UserEditorWindow.sceneID, value: value)
            } label: {
                Label("Properties", systemImage: "info.circle")
            }
        }
    }
}

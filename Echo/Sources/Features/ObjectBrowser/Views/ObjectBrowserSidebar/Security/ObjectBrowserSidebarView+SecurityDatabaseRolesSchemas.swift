import SwiftUI
import SQLServerKit

// MARK: - Database Roles and Application Roles

extension ObjectBrowserSidebarView {
    // MARK: - Database Roles (MSSQL)

    @ViewBuilder
    func dbRolesSection(session: ConnectionSession, dbKey: String) -> some View {
        let roles = viewModel.dbSecurityRolesByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecurityRolesExpandedByDB[dbKey] ?? false
        let dbName = databaseNameFromKey(dbKey)

        securitySectionHeader(
            depth: SecuritySidebarDepth.databaseSection,
            title: "Database Roles",
            icon: "shield",
            count: roles.count,
            isExpanded: Binding<Bool>(
                get: { isExpanded },
                set: { newValue in viewModel.dbSecurityRolesExpandedByDB[dbKey] = newValue }
            )
        )

        if isExpanded {
            if roles.isEmpty {
                SidebarRow(
                    depth: SecuritySidebarDepth.databaseLeaf,
                    icon: .none,
                    label: "No database roles found",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                )
            } else {
                ForEach(roles) { role in
                    dbRoleRow(role: role, session: session, databaseName: dbName)
                }
                .transition(.opacity)
            }
        }
    }

    func dbRoleRow(role: ObjectBrowserSidebarViewModel.SecurityDatabaseRoleItem, session: ConnectionSession, databaseName: String) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return SidebarRow(
            depth: SecuritySidebarDepth.databaseLeaf,
            icon: .system("shield"),
            label: role.name,
            iconColor: ExplorerSidebarPalette.folderIconColor(title: "Database Roles", colored: colored)
        ) {
            if role.isFixed {
                Text("Fixed")
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.quaternary)
            }
        }
        .contextMenu {
            // Group 3: Open / View
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

            // Group 6: Script as
            if !role.isFixed {
                Divider()
                Menu("Script as", systemImage: "scroll") {
                    Button {
                        openScriptTab(sql: "CREATE ROLE [\(role.name)];", session: session)
                    } label: {
                        Label("CREATE", systemImage: "plus.rectangle.on.rectangle")
                    }
                    Divider()
                    Button {
                        openScriptTab(sql: "DROP ROLE [\(role.name)];", session: session)
                    } label: {
                        Label("DROP", systemImage: "trash")
                    }
                }
            }

            Divider()

            // Group 10: Properties — ALWAYS last
            Button {
                let value = environmentState.prepareRoleEditorWindow(
                    connectionSessionID: session.connection.id,
                    database: databaseName,
                    existingRole: role.name
                )
                openWindow(id: RoleEditorWindow.sceneID, value: value)
            } label: {
                Label("Properties", systemImage: "info.circle")
            }
        }
    }

    // MARK: - Application Roles (MSSQL)

    @ViewBuilder
    func dbAppRolesSection(session: ConnectionSession, dbKey: String) -> some View {
        let appRoles = viewModel.dbSecurityAppRolesByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecurityAppRolesExpandedByDB[dbKey] ?? false

        securitySectionHeader(
            depth: SecuritySidebarDepth.databaseSection,
            title: "Application Roles",
            icon: "app.badge",
            count: appRoles.count,
            isExpanded: Binding<Bool>(
                get: { isExpanded },
                set: { newValue in viewModel.dbSecurityAppRolesExpandedByDB[dbKey] = newValue }
            )
        )

        if isExpanded {
            if appRoles.isEmpty {
                SidebarRow(
                    depth: SecuritySidebarDepth.databaseLeaf,
                    icon: .none,
                    label: "No application roles found",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                )
            } else {
                ForEach(appRoles) { appRole in
                    dbAppRoleRow(appRole: appRole, session: session)
                }
                .transition(.opacity)
            }
        }
    }

    func dbAppRoleRow(appRole: ObjectBrowserSidebarViewModel.SecurityAppRoleItem, session: ConnectionSession) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return SidebarRow(
            depth: SecuritySidebarDepth.databaseLeaf,
            icon: .system("app.badge"),
            label: appRole.name,
            iconColor: ExplorerSidebarPalette.folderIconColor(title: "Application Roles", colored: colored)
        ) {
            if let schema = appRole.defaultSchema, !schema.isEmpty {
                Text(schema)
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    openScriptTab(
                        sql: "CREATE APPLICATION ROLE [\(appRole.name)] WITH PASSWORD = N'<password>'\(appRole.defaultSchema.map { ", DEFAULT_SCHEMA = [\($0)]" } ?? "");",
                        session: session
                    )
                } label: {
                    Label("CREATE", systemImage: "plus.rectangle.on.rectangle")
                }
                Divider()
                Button {
                    openScriptTab(sql: "DROP APPLICATION ROLE [\(appRole.name)];", session: session)
                } label: {
                    Label("DROP", systemImage: "trash")
                }
            }
        }
    }
}

import SwiftUI
import SQLServerKit

// MARK: - Database Roles and Application Roles

extension ObjectBrowserSidebarView {
    // MARK: - Database Roles (MSSQL)

    @ViewBuilder
    func dbRolesSection(session: ConnectionSession, dbKey: String) -> some View {
        let roles = viewModel.dbSecurityRolesByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecurityRolesExpandedByDB[dbKey] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                depth: SecuritySidebarDepth.databaseSection,
                title: "Database Roles",
                icon: "shield",
                count: roles.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.dbSecurityRolesExpandedByDB[dbKey] = !isExpanded
                }
            }

            if isExpanded {
                ForEach(roles) { role in
                    dbRoleRow(role: role, session: session)
                }
            }
        }
    }

    func dbRoleRow(role: ObjectBrowserSidebarViewModel.SecurityDatabaseRoleItem, session: ConnectionSession) -> some View {
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
                depth: SecuritySidebarDepth.databaseSection,
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
                ForEach(appRoles) { appRole in
                    dbAppRoleRow(appRole: appRole, session: session)
                }
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
}

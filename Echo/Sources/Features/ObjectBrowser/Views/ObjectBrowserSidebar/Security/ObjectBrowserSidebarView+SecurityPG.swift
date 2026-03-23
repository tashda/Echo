import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Server-Level Security Sections

extension ObjectBrowserSidebarView {
    // MARK: - PostgreSQL: Login Roles (separate folder)

    @ViewBuilder
    func pgLoginRolesSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let allRoles = viewModel.securityLoginsBySession[connID] ?? []
        let loginRoles = allRoles.filter { $0.loginType.contains("Login") || $0.loginType.contains("Superuser") }
        let isExpanded = viewModel.securityPGLoginRolesExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                depth: SecuritySidebarDepth.serverSection,
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
                Button {
                    Task {
                        let handle = AppDirector.shared.activityEngine.begin("Refreshing login roles", connectionSessionID: session.id)
                        await loadServerSecurityAsync(session: session)
                        handle.succeed()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    viewModel.securityPGRoleSheetSessionID = connID
                    viewModel.securityPGRoleSheetEditName = nil
                    viewModel.showSecurityPGRoleSheet = true
                } label: {
                    Label("New Login Role", systemImage: "person.badge.plus")
                }
                .disabled(!(session.permissions?.canManageRoles ?? true))
            }

            if isExpanded {
                ForEach(loginRoles) { role in
                    pgRoleRow(role: role, session: session)
                }
            }
        }
    }

    // MARK: - PostgreSQL: Group Roles (separate folder)

    @ViewBuilder
    func pgGroupRolesSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let allRoles = viewModel.securityLoginsBySession[connID] ?? []
        let groupRoles = allRoles.filter { $0.loginType == "Group Role" }
        let isExpanded = viewModel.securityPGGroupRolesExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                depth: SecuritySidebarDepth.serverSection,
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
                Button {
                    Task {
                        let handle = AppDirector.shared.activityEngine.begin("Refreshing group roles", connectionSessionID: session.id)
                        await loadServerSecurityAsync(session: session)
                        handle.succeed()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    viewModel.securityPGRoleSheetSessionID = connID
                    viewModel.securityPGRoleSheetEditName = nil
                    viewModel.showSecurityPGRoleSheet = true
                } label: {
                    Label("New Group Role", systemImage: "person.2.badge.plus")
                }
                .disabled(!(session.permissions?.canManageRoles ?? true))
            }

            if isExpanded {
                ForEach(groupRoles) { role in
                    pgRoleRow(role: role, session: session)
                }
            }
        }
    }

    func pgRoleRow(role: ObjectBrowserSidebarViewModel.SecurityLoginItem, session: ConnectionSession) -> some View {
        let iconName = role.loginType.contains("Login") || role.loginType.contains("Superuser") ? "person.crop.circle" : "person.2.circle"

        let isColorful = projectStore.globalSettings.sidebarIconColorMode == .colorful
        let iconColor = ExplorerSidebarPalette.folderIconColor(title: "Users", colored: isColorful)

        return SidebarRow(
            depth: SecuritySidebarDepth.serverLeaf,
            icon: .system(iconName),
            label: role.name,
            iconColor: iconColor
        )
 {
            Text(role.loginType)
                .font(SidebarRowConstants.trailingFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .contextMenu {
            // Group 7: Maintenance
            Button {
                Task { await reassignPGRole(name: role.name, session: session) }
            } label: {
                Label("Reassign Owned Objects", systemImage: "arrow.triangle.swap")
            }
            .disabled(!(session.permissions?.canManageRoles ?? true))

            Divider()

            // Group 6: Script as
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let loginAttr = role.loginType.contains("Login") || role.loginType.contains("Superuser") ? " LOGIN" : ""
                    openScriptTab(sql: "CREATE ROLE \"\(role.name)\"\(loginAttr);", session: session)
                } label: {
                    Label("CREATE", systemImage: "plus.rectangle.on.rectangle")
                }
                Divider()
                Button {
                    openScriptTab(sql: "DROP ROLE \"\(role.name)\";", session: session)
                } label: {
                    Label("DROP", systemImage: "trash")
                }
            }

            Divider()

            // Group 9: Destructive
            Button(role: .destructive) {
                viewModel.dropSecurityPrincipalTarget = .init(
                    sessionID: session.id,
                    connectionID: session.connection.id,
                    name: role.name,
                    kind: .pgRole,
                    databaseName: nil
                )
                viewModel.showDropSecurityPrincipalAlert = true
            } label: {
                Label("Drop Role", systemImage: "trash")
            }
            .disabled(!(session.permissions?.canManageRoles ?? true))

            Divider()

            // Group 10: Properties — ALWAYS last
            Button {
                viewModel.securityPGRoleSheetSessionID = session.connection.id
                viewModel.securityPGRoleSheetEditName = role.name
                viewModel.showSecurityPGRoleSheet = true
            } label: {
                Label("Properties", systemImage: "info.circle")
            }
        }
    }

}

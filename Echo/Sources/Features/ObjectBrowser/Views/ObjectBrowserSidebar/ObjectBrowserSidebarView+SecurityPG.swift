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
                    viewModel.securityPGRoleSheetSessionID = connID
                    viewModel.securityPGRoleSheetEditName = nil
                    viewModel.showSecurityPGRoleSheet = true
                } label: {
                    Label("New Login Role\u{2026}", systemImage: "plus")
                }
                Divider()
                Button {
                    loadServerSecurity(session: session)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(loginRoles) { role in
                        pgRoleRow(role: role, session: session)
                    }

                }
                .padding(.leading, SidebarRowConstants.indentStep)
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
                    viewModel.securityPGRoleSheetSessionID = connID
                    viewModel.securityPGRoleSheetEditName = nil
                    viewModel.showSecurityPGRoleSheet = true
                } label: {
                    Label("New Group Role\u{2026}", systemImage: "plus")
                }
                Divider()
                Button {
                    loadServerSecurity(session: session)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groupRoles) { role in
                        pgRoleRow(role: role, session: session)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    func pgRoleRow(role: ObjectBrowserSidebarViewModel.SecurityLoginItem, session: ConnectionSession) -> some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: role.loginType.contains("Login") || role.loginType.contains("Superuser") ? "person.crop.circle" : "person.2.circle")
                .font(SidebarRowConstants.iconFont)
                .foregroundStyle(ExplorerSidebarPalette.security)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(role.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)

            Spacer(minLength: SpacingTokens.xxxs)

            Text(role.loginType)
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                Task { await reassignPGRole(name: role.name, session: session) }
            } label: {
                Label("Reassign Owned Objects\u{2026}", systemImage: "arrow.triangle.swap")
            }
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
            Divider()
            Menu {
                Button("CREATE") {
                    let loginAttr = role.loginType.contains("Login") || role.loginType.contains("Superuser") ? " LOGIN" : ""
                    openScriptTab(sql: "CREATE ROLE \"\(role.name)\"\(loginAttr);", session: session)
                }
                Button("DROP") {
                    openScriptTab(sql: "DROP ROLE \"\(role.name)\";", session: session)
                }
            } label: {
                Label("Script as", systemImage: "scroll")
            }
            Divider()
            Button {
                viewModel.securityPGRoleSheetSessionID = session.connection.id
                viewModel.securityPGRoleSheetEditName = role.name
                viewModel.showSecurityPGRoleSheet = true
            } label: {
                Label("Properties\u{2026}", systemImage: "info.circle")
            }
        }
    }

}

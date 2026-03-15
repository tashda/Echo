import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Flat List Row Security Sections

extension ObjectBrowserSidebarView {

    // MARK: - PostgreSQL Login Roles (Flat)

    @ViewBuilder
    func pgLoginRolesListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let allRoles = viewModel.securityLoginsBySession[connID] ?? []
        let loginRoles = allRoles.filter { $0.loginType.contains("Login") || $0.loginType.contains("Superuser") }
        let isExpanded = viewModel.securityPGLoginRolesExpandedBySession[connID] ?? false

        sidebarListRow(leading: baseIndent) {
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
        }

        if isExpanded {
            ForEach(loginRoles) { role in
                sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                    pgRoleRow(role: role, session: session)
                }
            }
        }
    }

    // MARK: - PostgreSQL Group Roles (Flat)

    @ViewBuilder
    func pgGroupRolesListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let allRoles = viewModel.securityLoginsBySession[connID] ?? []
        let groupRoles = allRoles.filter { $0.loginType == "Group Role" }
        let isExpanded = viewModel.securityPGGroupRolesExpandedBySession[connID] ?? false

        sidebarListRow(leading: baseIndent) {
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
        }

        if isExpanded {
            ForEach(groupRoles) { role in
                sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                    pgRoleRow(role: role, session: session)
                }
            }
        }
    }
}

import SwiftUI
import SQLServerKit

// MARK: - MSSQL Flat List Row Security Sections

extension ObjectBrowserSidebarView {

    // MARK: - MSSQL Logins (Flat)

    @ViewBuilder
    func loginsListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let allLogins = viewModel.securityLoginsBySession[connID] ?? []
        let standardLogins = allLogins.filter { !Self.certificateLoginTypes.contains($0.loginType) }
        let certLogins = allLogins.filter { Self.certificateLoginTypes.contains($0.loginType) }
        let isExpanded = viewModel.securityLoginsExpandedBySession[connID] ?? false

        sidebarListRow(leading: baseIndent) {
            securitySectionHeader(
                depth: 0,
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
                Button {
                    Task {
                        let handle = AppDirector.shared.activityEngine.begin("Refreshing logins", connectionSessionID: session.id)
                        await loadServerSecurityAsync(session: session)
                        handle.succeed()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    viewModel.securityLoginSheetSessionID = connID
                    viewModel.securityLoginSheetEditName = nil
                    viewModel.showSecurityLoginSheet = true
                } label: {
                    Label("New Login", systemImage: "person.badge.plus")
                }
            }
        }

        if isExpanded {
            ForEach(standardLogins) { login in
                sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                    loginRow(login: login, session: session)
                }
            }

            if !certLogins.isEmpty {
                certificateLoginsListRows(certLogins: certLogins, session: session, baseIndent: baseIndent + SidebarRowConstants.indentStep)
            }
        }
    }

    @ViewBuilder
    func certificateLoginsListRows(certLogins: [ObjectBrowserSidebarViewModel.SecurityLoginItem], session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityCertLoginsExpandedBySession[connID] ?? false

        sidebarListRow(leading: baseIndent) {
            securitySectionHeader(
                depth: 0,
                title: "Certificate Logins",
                icon: "doc.badge.lock",
                count: certLogins.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityCertLoginsExpandedBySession[connID] = !isExpanded
                }
            }
        }

        if isExpanded {
            ForEach(certLogins) { login in
                sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                    loginRow(login: login, session: session)
                }
            }
        }
    }

    // MARK: - MSSQL Server Roles (Flat)

    @ViewBuilder
    func serverRolesListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let roles = viewModel.securityServerRolesBySession[connID] ?? []
        let isExpanded = viewModel.securityServerRolesExpandedBySession[connID] ?? false

        sidebarListRow(leading: baseIndent) {
            securitySectionHeader(
                depth: 0,
                title: "Server Roles",
                icon: "shield",
                count: roles.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityServerRolesExpandedBySession[connID] = !isExpanded
                }
            }
            .contextMenu {
                Button {
                    Task {
                        let handle = AppDirector.shared.activityEngine.begin("Refreshing server roles", connectionSessionID: session.id)
                        await loadServerSecurityAsync(session: session)
                        handle.succeed()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    Task { await createMSSQLServerRole(session: session) }
                } label: {
                    Label("New Server Role", systemImage: "person.2.badge.plus")
                }
            }
        }

        if isExpanded {
            ForEach(roles) { role in
                sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                    serverRoleRow(role: role, session: session)
                }
            }
        }
    }

    // MARK: - MSSQL Credentials (Flat)

    @ViewBuilder
    func credentialsListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let credentials = viewModel.securityCredentialsBySession[connID] ?? []
        let isExpanded = viewModel.securityCredentialsExpandedBySession[connID] ?? false

        sidebarListRow(leading: baseIndent) {
            securitySectionHeader(
                depth: 0,
                title: "Credentials",
                icon: "key",
                count: credentials.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityCredentialsExpandedBySession[connID] = !isExpanded
                }
            }
        }

        if isExpanded {
            if credentials.isEmpty {
                sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                    HStack(spacing: SpacingTokens.xs) {
                        Spacer().frame(width: SidebarRowConstants.chevronWidth)
                        Text("No credentials found")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
                    .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                }
            } else {
                ForEach(credentials) { credential in
                    sidebarListRow(leading: baseIndent + SidebarRowConstants.indentStep) {
                        credentialRow(credential: credential, session: session)
                    }
                }
            }
        }
    }
}

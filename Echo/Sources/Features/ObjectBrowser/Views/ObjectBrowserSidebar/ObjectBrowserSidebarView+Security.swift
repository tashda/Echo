import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Server-Level Security Folder

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func securityFolderSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityFolderExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
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
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    serverSecurityContent(session: session)
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    // MARK: - Flat List Row Security (for per-item context menus)

    @ViewBuilder
    func securityFolderListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityFolderExpandedBySession[connID] ?? false

        sidebarListRow(leading: baseIndent) {
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
            .contextMenu {
                securityFolderContextMenu(session: session)
            }
        }

        if isExpanded {
            serverSecurityListRows(session: session, baseIndent: baseIndent + SidebarRowConstants.indentStep)
        }
    }

    @ViewBuilder
    func serverSecurityListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let isLoading = viewModel.securityServerLoadingBySession[connID] ?? false
        let hasData = !(viewModel.securityLoginsBySession[connID] ?? []).isEmpty
            || !(viewModel.securityServerRolesBySession[connID] ?? []).isEmpty

        if isLoading && !hasData {
            sidebarListRow(leading: baseIndent) {
                securityLoadingRow("Loading security\u{2026}")
            }
        }

        switch session.connection.databaseType {
        case .microsoftSQL:
            loginsListRows(session: session, baseIndent: baseIndent)
            serverRolesListRows(session: session, baseIndent: baseIndent)
            credentialsListRows(session: session, baseIndent: baseIndent)
        case .postgresql:
            pgLoginRolesListRows(session: session, baseIndent: baseIndent)
            pgGroupRolesListRows(session: session, baseIndent: baseIndent)
        default:
            EmptyView()
        }
    }

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
                    viewModel.securityLoginSheetSessionID = connID
                    viewModel.securityLoginSheetEditName = nil
                    viewModel.showSecurityLoginSheet = true
                } label: {
                    Label("New Login\u{2026}", systemImage: "plus")
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
                title: "Server Roles",
                icon: "shield.fill",
                count: roles.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityServerRolesExpandedBySession[connID] = !isExpanded
                }
            }
            .contextMenu {
                Button {
                    Task { await createMSSQLServerRole(session: session) }
                } label: {
                    Label("New Server Role\u{2026}", systemImage: "plus")
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

    @ViewBuilder
    func serverSecurityContent(session: ConnectionSession) -> some View {
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

}

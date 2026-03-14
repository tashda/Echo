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
    private func serverSecurityListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
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
    private func loginsListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
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
    private func certificateLoginsListRows(certLogins: [ObjectBrowserSidebarViewModel.SecurityLoginItem], session: ConnectionSession, baseIndent: CGFloat) -> some View {
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
    private func serverRolesListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
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
    private func credentialsListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
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
    private func pgLoginRolesListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
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
    private func pgGroupRolesListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
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
    private func serverSecurityContent(session: ConnectionSession) -> some View {
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

    // MARK: - MSSQL: Logins

    /// Logins that use certificate or asymmetric key authentication.
    private static let certificateLoginTypes: Set<String> = ["Certificate", "Asymmetric Key"]

    @ViewBuilder
    private func loginsSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let allLogins = viewModel.securityLoginsBySession[connID] ?? []
        let standardLogins = allLogins.filter { !Self.certificateLoginTypes.contains($0.loginType) }
        let certLogins = allLogins.filter { Self.certificateLoginTypes.contains($0.loginType) }
        let isExpanded = viewModel.securityLoginsExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
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

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(standardLogins) { login in
                        loginRow(login: login, session: session)
                    }

                    // Certificates subfolder
                    if !certLogins.isEmpty {
                        certificateLoginsSubfolder(certLogins: certLogins, session: session)
                    }

                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    @ViewBuilder
    private func certificateLoginsSubfolder(certLogins: [ObjectBrowserSidebarViewModel.SecurityLoginItem], session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityCertLoginsExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
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

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(certLogins) { login in
                        loginRow(login: login, session: session)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func loginRow(login: ObjectBrowserSidebarViewModel.SecurityLoginItem, session: ConnectionSession) -> some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: login.isDisabled ? "person.crop.circle.badge.xmark" : "person.crop.circle")
                .font(SidebarRowConstants.iconFont)
                .foregroundStyle(login.isDisabled ? Color(nsColor: .quaternaryLabelColor) : ExplorerSidebarPalette.security)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(login.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(login.isDisabled ? .secondary : .primary)
                .lineLimit(1)

            Spacer(minLength: SpacingTokens.xxxs)

            Text(login.loginType)
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.tertiary)

            if login.isDisabled {
                Text("Disabled")
                    .font(TypographyTokens.label)
                    .foregroundStyle(ColorTokens.Text.quaternary)
            }
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            if login.isDisabled {
                Button {
                    Task { await enableMSSQLLogin(name: login.name, enabled: true, session: session) }
                } label: {
                    Label("Enable Login", systemImage: "checkmark.circle")
                }
            } else {
                Button {
                    Task { await enableMSSQLLogin(name: login.name, enabled: false, session: session) }
                } label: {
                    Label("Disable Login", systemImage: "nosign")
                }
            }
            Divider()
            Button(role: .destructive) {
                viewModel.dropSecurityPrincipalTarget = .init(
                    sessionID: session.id,
                    connectionID: session.connection.id,
                    name: login.name,
                    kind: .mssqlLogin,
                    databaseName: nil
                )
                viewModel.showDropSecurityPrincipalAlert = true
            } label: {
                Label("Drop Login", systemImage: "trash")
            }
            Divider()
            Menu {
                Button("CREATE") {
                    let sql: String
                    if login.loginType == "SQL" {
                        sql = "CREATE LOGIN [\(login.name)] WITH PASSWORD = N'<password>';"
                    } else {
                        sql = "CREATE LOGIN [\(login.name)] FROM WINDOWS;"
                    }
                    openScriptTab(sql: sql, session: session)
                }
                Button("DROP") {
                    openScriptTab(sql: "DROP LOGIN [\(login.name)];", session: session)
                }
            } label: {
                Label("Script as", systemImage: "scroll")
            }
            Divider()
            Button {
                viewModel.securityLoginSheetSessionID = session.connection.id
                viewModel.securityLoginSheetEditName = login.name
                viewModel.showSecurityLoginSheet = true
            } label: {
                Label("Properties\u{2026}", systemImage: "info.circle")
            }
        }
    }

    // MARK: - MSSQL: Server Roles

    @ViewBuilder
    private func serverRolesSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let roles = viewModel.securityServerRolesBySession[connID] ?? []
        let isExpanded = viewModel.securityServerRolesExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
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

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(roles) { role in
                        serverRoleRow(role: role, session: session)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func serverRoleRow(role: ObjectBrowserSidebarViewModel.SecurityServerRoleItem, session: ConnectionSession) -> some View {
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
                    SELECT m.name AS member_name, m.type_desc
                    FROM sys.server_role_members rm
                    JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
                    JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
                    WHERE r.name = N'\(role.name)';
                    """,
                    session: session
                )
            } label: {
                Label("List Members", systemImage: "person.2")
            }
            if !role.isFixed {
                Divider()
                Button(role: .destructive) {
                    viewModel.dropSecurityPrincipalTarget = .init(
                        sessionID: session.id,
                        connectionID: session.connection.id,
                        name: role.name,
                        kind: .mssqlServerRole,
                        databaseName: nil
                    )
                    viewModel.showDropSecurityPrincipalAlert = true
                } label: {
                    Label("Drop Server Role", systemImage: "trash")
                }
                Divider()
                Menu {
                    Button("CREATE") {
                        openScriptTab(sql: "CREATE SERVER ROLE [\(role.name)];", session: session)
                    }
                    Button("DROP") {
                        openScriptTab(sql: "DROP SERVER ROLE [\(role.name)];", session: session)
                    }
                } label: {
                    Label("Script as", systemImage: "scroll")
                }
            }
        }
    }

    // MARK: - MSSQL: Credentials

    @ViewBuilder
    private func credentialsSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let credentials = viewModel.securityCredentialsBySession[connID] ?? []
        let isExpanded = viewModel.securityCredentialsExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
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

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    if credentials.isEmpty {
                        HStack(spacing: SpacingTokens.xs) {
                            Spacer().frame(width: SidebarRowConstants.chevronWidth)
                            Text("No credentials found")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
                        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                    } else {
                        ForEach(credentials) { credential in
                            credentialRow(credential: credential, session: session)
                        }
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func credentialRow(credential: ObjectBrowserSidebarViewModel.SecurityCredentialItem, session: ConnectionSession) -> some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: "key")
                .font(SidebarRowConstants.iconFont)
                .foregroundStyle(ExplorerSidebarPalette.security)
                .frame(width: SidebarRowConstants.iconFrame)

            Text(credential.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)

            Spacer(minLength: SpacingTokens.xxxs)

            Text(credential.identity)
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .lineLimit(1)
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
        .contextMenu {
            Menu {
                Button("CREATE") {
                    openScriptTab(
                        sql: "CREATE CREDENTIAL [\(credential.name)] WITH IDENTITY = N'\(credential.identity)', SECRET = N'<secret>';",
                        session: session
                    )
                }
                Button("DROP") {
                    openScriptTab(sql: "DROP CREDENTIAL [\(credential.name)];", session: session)
                }
            } label: {
                Label("Script as", systemImage: "scroll")
            }
        }
    }

    // MARK: - PostgreSQL: Login Roles (separate folder)

    @ViewBuilder
    private func pgLoginRolesSection(session: ConnectionSession) -> some View {
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
    private func pgGroupRolesSection(session: ConnectionSession) -> some View {
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

    private func pgRoleRow(role: ObjectBrowserSidebarViewModel.SecurityLoginItem, session: ConnectionSession) -> some View {
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
    private func databaseSecurityContent(database: DatabaseInfo, session: ConnectionSession, dbKey: String) -> some View {
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
    private func dbUsersSection(session: ConnectionSession, dbKey: String) -> some View {
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

    private func dbUserRow(user: ObjectBrowserSidebarViewModel.SecurityUserItem, session: ConnectionSession, databaseName: String) -> some View {
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
    private func dbRolesSection(session: ConnectionSession, dbKey: String) -> some View {
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

    private func dbRoleRow(role: ObjectBrowserSidebarViewModel.SecurityDatabaseRoleItem, session: ConnectionSession) -> some View {
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
    private func dbAppRolesSection(session: ConnectionSession, dbKey: String) -> some View {
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

    private func dbAppRoleRow(appRole: ObjectBrowserSidebarViewModel.SecurityAppRoleItem, session: ConnectionSession) -> some View {
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
    private func dbSchemasSection(session: ConnectionSession, dbKey: String) -> some View {
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

    private func dbSchemaRow(schema: ObjectBrowserSidebarViewModel.SecuritySchemaItem, session: ConnectionSession) -> some View {
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

    // MARK: - Security Folder Context Menu

    @ViewBuilder
    private func securityFolderContextMenu(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        switch session.connection.databaseType {
        case .microsoftSQL:
            Button {
                viewModel.securityLoginSheetSessionID = connID
                viewModel.securityLoginSheetEditName = nil
                viewModel.showSecurityLoginSheet = true
            } label: {
                Label("New Login\u{2026}", systemImage: "plus")
            }
        case .postgresql:
            Button {
                viewModel.securityPGRoleSheetSessionID = connID
                viewModel.securityPGRoleSheetEditName = nil
                viewModel.showSecurityPGRoleSheet = true
            } label: {
                Label("New Login Role\u{2026}", systemImage: "plus")
            }
            Button {
                viewModel.securityPGRoleSheetSessionID = connID
                viewModel.securityPGRoleSheetEditName = nil
                viewModel.showSecurityPGRoleSheet = true
            } label: {
                Label("New Group Role\u{2026}", systemImage: "plus")
            }
        default:
            EmptyView()
        }

        Divider()

        Button {
            loadServerSecurity(session: session)
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }

    // MARK: - Shared UI Helpers

    func securitySectionHeader(title: String, icon: String, count: Int?, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        folderHeaderRow(title: title, icon: icon, count: count, isExpanded: isExpanded, action: action)
    }

    func securityLoadingRow(_ text: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)
            ProgressView()
                .controlSize(.mini)
            Text(text)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
    }

    // MARK: - New Item Button

    func newItemButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xs) {
                Spacer().frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: "plus.circle")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(title)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)

                Spacer(minLength: SpacingTokens.xxxs)
            }
            .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Key Helpers

    /// Extracts the database name from a composite key like "UUID#dbName"
    private func databaseNameFromKey(_ key: String) -> String {
        if let hashIndex = key.firstIndex(of: "#") {
            return String(key[key.index(after: hashIndex)...])
        }
        return key
    }

    // MARK: - Script Helper

    private func openScriptTab(sql: String, session: ConnectionSession) {
        environmentState.openQueryTab(for: session, presetQuery: sql)
    }

    // MARK: - MSSQL Actions

    private func dropMSSQLLogin(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.serverSecurity
            try await ssec.dropLogin(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "Login '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    private func dropMSSQLUser(name: String, database: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            _ = try? await session.session.simpleQuery("USE [\(database)]")
            let sec = mssql.security
            try await sec.dropUser(name: name)
            // Reload db security
            if let structure = session.databaseStructure,
               let db = structure.databases.first(where: { $0.name == database }) {
                loadDatabaseSecurity(database: db, session: session)
            }
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "User '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    private func createMSSQLServerRole(session: ConnectionSession) async {
        // Open a script tab with a CREATE SERVER ROLE template
        openScriptTab(sql: "CREATE SERVER ROLE [NewServerRole];", session: session)
    }

    private func dropMSSQLServerRole(name: String, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.serverSecurity
            try await ssec.dropServerRole(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "Server role '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    // MARK: - Drop Security Principal Dispatch

    func executeDropSecurityPrincipal(_ target: ObjectBrowserSidebarViewModel.DropSecurityPrincipalTarget, session: ConnectionSession) async {
        switch target.kind {
        case .pgRole:
            await dropPGRole(name: target.name, session: session)
        case .mssqlLogin:
            await dropMSSQLLogin(name: target.name, session: session)
        case .mssqlUser:
            if let db = target.databaseName {
                await dropMSSQLUser(name: target.name, database: db, session: session)
            }
        case .mssqlServerRole:
            await dropMSSQLServerRole(name: target.name, session: session)
        }
    }

    // MARK: - Error Formatting

    private func readableErrorMessage(_ error: Error) -> String {
        // PostgresKit's PostgresError already provides good messages via LocalizedError.
        if let pgError = error as? PostgresKit.PostgresError {
            return pgError.message
        }
        // PSQLError now conforms to @retroactive LocalizedError in postgres-wire,
        // so localizedDescription returns the actual server message.
        return error.localizedDescription
    }

    // MARK: - PostgreSQL Actions

    private func dropPGRole(name: String, session: ConnectionSession) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            try await pg.client.security.dropUser(name: name)
            loadServerSecurity(session: session)
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityDropped, message: "Role '\(name)' dropped")
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(readableErrorMessage(error))")
            }
        }
    }

    private func reassignPGRole(name: String, session: ConnectionSession) async {
        guard session.session is PostgresSession else { return }
        // Open a script tab with a REASSIGN OWNED template
        let sql = """
        -- Reassign all objects owned by "\(name)" to another role.
        -- Replace "target_role" with the role to receive the objects.
        REASSIGN OWNED BY "\(name)" TO "target_role";
        """
        openScriptTab(sql: sql, session: session)
    }

    // MARK: - MSSQL Login Enable/Disable

    private func enableMSSQLLogin(name: String, enabled: Bool, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            let ssec = mssql.serverSecurity
            try await ssec.enableLogin(name: name, enabled: enabled)
            loadServerSecurity(session: session)
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .securityToggleFailed, message: "Failed to \(enabled ? "enable" : "disable") login: \(readableErrorMessage(error))")
            }
        }
    }

    // MARK: - Login Type Display

    private func loginTypeDisplayName(_ type: ServerLoginType) -> String {
        switch type {
        case .sql: return "SQL"
        case .windowsUser: return "Windows"
        case .windowsGroup: return "Windows Group"
        case .certificate: return "Certificate"
        case .asymmetricKey: return "Asymmetric Key"
        case .external: return "External"
        }
    }

    // MARK: - Server-Level Security Data Loading

    func loadServerSecurityIfNeeded(session: ConnectionSession) {
        let connID = session.connection.id
        let hasData = !(viewModel.securityLoginsBySession[connID] ?? []).isEmpty
        let isLoading = viewModel.securityServerLoadingBySession[connID] ?? false
        if !hasData && !isLoading {
            loadServerSecurity(session: session)
        }
    }

    func loadServerSecurity(session: ConnectionSession) {
        let connID = session.connection.id
        viewModel.securityServerLoadingBySession[connID] = true

        Task {
            switch session.connection.databaseType {
            case .microsoftSQL:
                await loadMSSQLServerSecurity(session: session, connID: connID)
            case .postgresql:
                await loadPostgresServerSecurity(session: session, connID: connID)
            default:
                break
            }

            await MainActor.run {
                viewModel.securityServerLoadingBySession[connID] = false
            }
        }
    }

    private func loadMSSQLServerSecurity(session: ConnectionSession, connID: UUID) async {
        guard let mssql = session.session as? MSSQLSession else { return }

        // Load logins (filter system logins by default)
        do {
            let ssec = mssql.serverSecurity
            let logins = try await ssec.listLogins(includeSystemLogins: false)
            let items = logins.map { login in
                ObjectBrowserSidebarViewModel.SecurityLoginItem(
                    id: login.name,
                    name: login.name,
                    loginType: loginTypeDisplayName(login.type),
                    isDisabled: login.isDisabled
                )
            }
            await MainActor.run { viewModel.securityLoginsBySession[connID] = items }
        } catch {
            await MainActor.run { viewModel.securityLoginsBySession[connID] = [] }
        }

        // Load server roles
        do {
            let ssec = mssql.serverSecurity
            let roles = try await ssec.listServerRoles()
            let items = roles.map { role in
                ObjectBrowserSidebarViewModel.SecurityServerRoleItem(
                    id: role.name,
                    name: role.name,
                    isFixed: role.isFixed
                )
            }
            await MainActor.run { viewModel.securityServerRolesBySession[connID] = items }
        } catch {
            await MainActor.run { viewModel.securityServerRolesBySession[connID] = [] }
        }

        // Load credentials
        do {
            let ssec = mssql.serverSecurity
            let creds = try await ssec.listCredentials()
            let items = creds.map { cred in
                ObjectBrowserSidebarViewModel.SecurityCredentialItem(
                    id: cred.name,
                    name: cred.name,
                    identity: cred.identity ?? ""
                )
            }
            await MainActor.run { viewModel.securityCredentialsBySession[connID] = items }
        } catch {
            await MainActor.run { viewModel.securityCredentialsBySession[connID] = [] }
        }
    }

    private func loadPostgresServerSecurity(session: ConnectionSession, connID: UUID) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            let roles = try await pg.client.security.listRoles()

            let items: [ObjectBrowserSidebarViewModel.SecurityLoginItem] = roles.map { role in
                let typeDesc: String
                if role.isSuperuser {
                    typeDesc = "Superuser"
                } else if role.canLogin {
                    typeDesc = "Login Role"
                } else {
                    typeDesc = "Group Role"
                }

                return ObjectBrowserSidebarViewModel.SecurityLoginItem(
                    id: role.name,
                    name: role.name,
                    loginType: typeDesc,
                    isDisabled: false
                )
            }
            await MainActor.run { viewModel.securityLoginsBySession[connID] = items }
        } catch {
            await MainActor.run { viewModel.securityLoginsBySession[connID] = [] }
        }
    }

    // MARK: - Database-Level Security Data Loading

    func loadDatabaseSecurityIfNeeded(database: DatabaseInfo, session: ConnectionSession) {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        let hasData = !(viewModel.dbSecurityUsersByDB[dbKey] ?? []).isEmpty
            || !(viewModel.dbSecuritySchemasByDB[dbKey] ?? []).isEmpty
        let isLoading = viewModel.dbSecurityLoadingByDB[dbKey] ?? false
        if !hasData && !isLoading {
            loadDatabaseSecurity(database: database, session: session)
        }
    }

    func loadDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession) {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        viewModel.dbSecurityLoadingByDB[dbKey] = true

        Task {
            switch session.connection.databaseType {
            case .microsoftSQL:
                await loadMSSQLDatabaseSecurity(database: database, session: session, dbKey: dbKey)
            case .postgresql:
                await loadPostgresDatabaseSecurity(database: database, session: session, dbKey: dbKey)
            default:
                break
            }

            await MainActor.run {
                viewModel.dbSecurityLoadingByDB[dbKey] = false
            }
        }
    }

    private func loadMSSQLDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession, dbKey: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        let dbName = database.name

        // Switch to target database for the security client
        _ = try? await session.session.simpleQuery("USE [\(dbName)]")
        let sec = mssql.security

        // Users
        do {
            let users = try await sec.listUsers()
            let items = users
                .filter { $0.name != "sys" && $0.name != "INFORMATION_SCHEMA" }
                .map { u in
                    ObjectBrowserSidebarViewModel.SecurityUserItem(
                        id: u.name,
                        name: u.name,
                        userType: String(describing: u.type),
                        defaultSchema: u.defaultSchema
                    )
                }
            await MainActor.run { viewModel.dbSecurityUsersByDB[dbKey] = items }
        } catch {
            await MainActor.run { viewModel.dbSecurityUsersByDB[dbKey] = [] }
        }

        // Database Roles
        do {
            let roles = try await sec.listRoles()
            let items = roles.map { r in
                ObjectBrowserSidebarViewModel.SecurityDatabaseRoleItem(
                    id: r.name,
                    name: r.name,
                    isFixed: r.isFixedRole,
                    owner: r.ownerPrincipalId.map { String($0) }
                )
            }
            await MainActor.run { viewModel.dbSecurityRolesByDB[dbKey] = items }
        } catch {
            await MainActor.run { viewModel.dbSecurityRolesByDB[dbKey] = [] }
        }

        // Application Roles
        // TODO: Use sec.listApplicationRoles() when made public in sqlserver-nio
        await MainActor.run { viewModel.dbSecurityAppRolesByDB[dbKey] = [] }

        // Schemas
        do {
            let schemas = try await sec.listSchemas()
            let systemSchemas: Set<String> = [
                "sys", "INFORMATION_SCHEMA", "guest",
                "db_owner", "db_accessadmin", "db_securityadmin",
                "db_ddladmin", "db_backupoperator", "db_datareader",
                "db_datawriter", "db_denydatareader", "db_denydatawriter"
            ]
            let items = schemas
                .filter { !systemSchemas.contains($0.name) }
                .map { s in
                    ObjectBrowserSidebarViewModel.SecuritySchemaItem(
                        id: s.name,
                        name: s.name,
                        owner: s.owner
                    )
                }
            await MainActor.run { viewModel.dbSecuritySchemasByDB[dbKey] = items }
        } catch {
            await MainActor.run { viewModel.dbSecuritySchemasByDB[dbKey] = [] }
        }
    }

    private func loadPostgresDatabaseSecurity(database: DatabaseInfo, session: ConnectionSession, dbKey: String) async {
        guard let pg = session.session as? PostgresSession else { return }
        do {
            let schemas = try await pg.client.introspection.listSchemas()

            let items = schemas.map { schema in
                ObjectBrowserSidebarViewModel.SecuritySchemaItem(
                    id: schema.name,
                    name: schema.name,
                    owner: schema.owner
                )
            }
            await MainActor.run { viewModel.dbSecuritySchemasByDB[dbKey] = items }
        } catch {
            await MainActor.run { viewModel.dbSecuritySchemasByDB[dbKey] = [] }
        }
    }
}

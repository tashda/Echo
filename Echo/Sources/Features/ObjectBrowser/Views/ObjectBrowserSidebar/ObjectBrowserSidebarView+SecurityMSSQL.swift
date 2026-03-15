import SwiftUI
import SQLServerKit

// MARK: - MSSQL Server-Level Security Sections

extension ObjectBrowserSidebarView {
    // MARK: - MSSQL: Logins

    /// Logins that use certificate or asymmetric key authentication.
    static let certificateLoginTypes: Set<String> = ["Certificate", "Asymmetric Key"]

    @ViewBuilder
    func loginsSection(session: ConnectionSession) -> some View {
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
    func certificateLoginsSubfolder(certLogins: [ObjectBrowserSidebarViewModel.SecurityLoginItem], session: ConnectionSession) -> some View {
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

    func loginRow(login: ObjectBrowserSidebarViewModel.SecurityLoginItem, session: ConnectionSession) -> some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)

            Image(systemName: login.isDisabled ? "person.crop.circle.badge.xmark" : "person.crop.circle")
                .font(SidebarRowConstants.iconFont)
                .foregroundStyle(login.isDisabled ? ColorTokens.Text.quaternary : ExplorerSidebarPalette.security)
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
    func serverRolesSection(session: ConnectionSession) -> some View {
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

    func serverRoleRow(role: ObjectBrowserSidebarViewModel.SecurityServerRoleItem, session: ConnectionSession) -> some View {
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
    func credentialsSection(session: ConnectionSession) -> some View {
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

    func credentialRow(credential: ObjectBrowserSidebarViewModel.SecurityCredentialItem, session: ConnectionSession) -> some View {
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

}

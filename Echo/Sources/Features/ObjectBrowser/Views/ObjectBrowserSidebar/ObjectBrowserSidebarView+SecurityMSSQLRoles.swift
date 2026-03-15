import SwiftUI
import SQLServerKit

// MARK: - MSSQL Server-Level Security Sections: Server Roles & Credentials

extension ObjectBrowserSidebarView {

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
            serverRoleRowContextMenu(role: role, session: session)
        }
    }

    @ViewBuilder
    private func serverRoleRowContextMenu(role: ObjectBrowserSidebarViewModel.SecurityServerRoleItem, session: ConnectionSession) -> some View {
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

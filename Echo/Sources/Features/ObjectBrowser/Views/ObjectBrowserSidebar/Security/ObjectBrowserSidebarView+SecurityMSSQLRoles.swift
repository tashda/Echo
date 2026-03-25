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

        securitySectionHeader(
            depth: SecuritySidebarDepth.serverSection,
            title: "Server Roles",
            icon: "shield",
            count: roles.count,
            isExpanded: Binding<Bool>(
                get: { viewModel.securityServerRolesExpandedBySession[connID] ?? false },
                set: { newValue in viewModel.securityServerRolesExpandedBySession[connID] = newValue }
            )
        )
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
                createMSSQLServerRole(session: session)
            } label: {
                Label("New Server Role", systemImage: "person.2.badge.plus")
            }
            .disabled(!(session.permissions?.canManageRoles ?? true))
        }

        if viewModel.securityServerRolesExpandedBySession[connID] ?? false {
            if roles.isEmpty {
                SidebarRow(
                    depth: SecuritySidebarDepth.serverLeaf,
                    icon: .none,
                    label: "No server roles found",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                )
            } else {
                ForEach(roles) { role in
                    serverRoleRow(role: role, session: session)
                }
            }
        }
    }

    func serverRoleRow(role: ObjectBrowserSidebarViewModel.SecurityServerRoleItem, session: ConnectionSession) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return SidebarRow(
            depth: SecuritySidebarDepth.serverLeaf,
            icon: .system("shield"),
            label: role.name,
            iconColor: ExplorerSidebarPalette.folderIconColor(title: "Server Roles", colored: colored)
        ) {
            if role.isFixed {
                Text("Fixed")
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.quaternary)
            }
        }
        .contextMenu {
            serverRoleRowContextMenu(role: role, session: session)
        }
    }

    @ViewBuilder
    private func serverRoleRowContextMenu(role: ObjectBrowserSidebarViewModel.SecurityServerRoleItem, session: ConnectionSession) -> some View {
        // Group 3: Open / View
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

            // Group 6: Script as
            Menu("Script as", systemImage: "scroll") {
                Button {
                    openScriptTab(sql: "CREATE SERVER ROLE [\(role.name)];", session: session)
                } label: {
                    Label("CREATE", systemImage: "plus.rectangle.on.rectangle")
                }
                Divider()
                Button {
                    openScriptTab(sql: "DROP SERVER ROLE [\(role.name)];", session: session)
                } label: {
                    Label("DROP", systemImage: "trash")
                }
            }

            Divider()

            // Group 10: Destructive
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
            .disabled(!(session.permissions?.canManageRoles ?? true))
        }
    }

    // MARK: - MSSQL: Credentials

    @ViewBuilder
    func credentialsSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let credentials = viewModel.securityCredentialsBySession[connID] ?? []
        let isExpanded = viewModel.securityCredentialsExpandedBySession[connID] ?? false

        securitySectionHeader(
            depth: SecuritySidebarDepth.serverSection,
            title: "Credentials",
            icon: "key",
            count: credentials.count,
            isExpanded: Binding<Bool>(
                get: { viewModel.securityCredentialsExpandedBySession[connID] ?? false },
                set: { newValue in viewModel.securityCredentialsExpandedBySession[connID] = newValue }
            )
        )
        .contextMenu {
            Button {
                createMSSQLCredential(session: session)
            } label: {
                Label("New Credential", systemImage: "key.badge.plus")
            }
            .disabled(!(session.permissions?.canManageRoles ?? true))
        }

        if viewModel.securityCredentialsExpandedBySession[connID] ?? false {
            if credentials.isEmpty {
                SidebarRow(
                    depth: SecuritySidebarDepth.serverLeaf,
                    icon: .none,
                    label: "No credentials found",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                )
            } else {
                ForEach(credentials) { credential in
                    credentialRow(credential: credential, session: session)
                }
            }
        }
    }

    func credentialRow(credential: ObjectBrowserSidebarViewModel.SecurityCredentialItem, session: ConnectionSession) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return SidebarRow(
            depth: SecuritySidebarDepth.serverLeaf,
            icon: .system("key"),
            label: credential.name,
            iconColor: ExplorerSidebarPalette.folderIconColor(title: "Credentials", colored: colored)
        ) {
            Text(credential.identity)
                .font(SidebarRowConstants.trailingFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .lineLimit(1)
        }
        .contextMenu {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    openScriptTab(
                        sql: "CREATE CREDENTIAL [\(credential.name)] WITH IDENTITY = N'\(credential.identity)', SECRET = N'<secret>';",
                        session: session
                    )
                } label: {
                    Label("CREATE", systemImage: "plus.rectangle.on.rectangle")
                }
                Divider()
                Button {
                    openScriptTab(sql: "DROP CREDENTIAL [\(credential.name)];", session: session)
                } label: {
                    Label("DROP", systemImage: "trash")
                }
            }
        }
    }
}

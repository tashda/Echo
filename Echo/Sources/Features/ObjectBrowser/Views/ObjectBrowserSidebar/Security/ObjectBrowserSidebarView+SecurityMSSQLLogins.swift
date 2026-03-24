import SwiftUI
import SQLServerKit

// MARK: - MSSQL Server-Level Security Sections: Logins

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

        securitySectionHeader(
            depth: SecuritySidebarDepth.serverSection,
            title: "Logins",
            icon: "person.2",
            count: standardLogins.count,
            isExpanded: Binding<Bool>(
                get: { isExpanded },
                set: { newValue in viewModel.securityLoginsExpandedBySession[connID] = newValue }
            )
        )
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
                let value = environmentState.prepareLoginEditorWindow(
                    connectionSessionID: connID,
                    existingLogin: nil
                )
                openWindow(id: LoginEditorWindow.sceneID, value: value)
            } label: {
                Label("New Login", systemImage: "person.badge.plus")
            }
            .disabled(!(session.permissions?.canManageRoles ?? true))
            .help(session.permissions?.canManageRoles ?? true ? "" : "Requires securityadmin or sysadmin role")
        }

        if isExpanded {
            if standardLogins.isEmpty && certLogins.isEmpty {
                SidebarRow(
                    depth: SecuritySidebarDepth.serverLeaf,
                    icon: .none,
                    label: "No logins found",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                )
            } else {
                ForEach(standardLogins) { login in
                    loginRow(login: login, session: session)
                }
                .transition(.opacity)

                // Certificates subfolder
                if !certLogins.isEmpty {
                    certificateLoginsSubfolder(certLogins: certLogins, session: session)
                }
            }
        }
    }

    @ViewBuilder
    func certificateLoginsSubfolder(certLogins: [ObjectBrowserSidebarViewModel.SecurityLoginItem], session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityCertLoginsExpandedBySession[connID] ?? false

        securitySectionHeader(
            depth: SecuritySidebarDepth.serverNestedSection,
            title: "Certificate Logins",
            icon: "doc.badge.lock",
            count: certLogins.count,
            isExpanded: Binding<Bool>(
                get: { isExpanded },
                set: { newValue in viewModel.securityCertLoginsExpandedBySession[connID] = newValue }
            )
        )

        if isExpanded {
            ForEach(certLogins) { login in
                loginRow(login: login, session: session, depth: 4)
            }
            .transition(.opacity)
        }
    }

    func loginRow(
        login: ObjectBrowserSidebarViewModel.SecurityLoginItem,
        session: ConnectionSession,
        depth: Int = SecuritySidebarDepth.serverLeaf
    ) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return SidebarRow(
            depth: depth,
            icon: .system(login.isDisabled ? "person.crop.circle.badge.xmark" : "person.crop.circle"),
            label: login.name,
            iconColor: login.isDisabled ? ColorTokens.Text.quaternary : ExplorerSidebarPalette.folderIconColor(title: "Logins", colored: colored),
            labelColor: login.isDisabled ? ColorTokens.Text.secondary : ColorTokens.Text.primary
        )
 {
            Text(login.loginType)
                .font(SidebarRowConstants.trailingFont)
                .foregroundStyle(ColorTokens.Text.tertiary)

            if login.isDisabled {
                Text("Disabled")
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.quaternary)
            }
        }
        .contextMenu {
            loginRowContextMenu(login: login, session: session)
        }
    }

    @ViewBuilder
    private func loginRowContextMenu(login: ObjectBrowserSidebarViewModel.SecurityLoginItem, session: ConnectionSession) -> some View {
        // Group 6: Script as
        Menu("Script as", systemImage: "scroll") {
            Button {
                let sql: String
                if login.loginType == "SQL" {
                    sql = "CREATE LOGIN [\(login.name)] WITH PASSWORD = N'<password>';"
                } else {
                    sql = "CREATE LOGIN [\(login.name)] FROM WINDOWS;"
                }
                openScriptTab(sql: sql, session: session)
            } label: {
                Label("CREATE", systemImage: "plus.rectangle.on.rectangle")
            }
            Divider()
            Button {
                openScriptTab(sql: "DROP LOGIN [\(login.name)];", session: session)
            } label: {
                Label("DROP", systemImage: "trash")
            }
        }

        Divider()

        // Group 8: Enable / Disable
        if login.isDisabled {
            Button {
                Task { await enableMSSQLLogin(name: login.name, enabled: true, session: session) }
            } label: {
                Label("Enable Login", systemImage: "checkmark.circle")
            }
            .disabled(!(session.permissions?.canManageRoles ?? true))
        } else {
            Button {
                Task { await enableMSSQLLogin(name: login.name, enabled: false, session: session) }
            } label: {
                Label("Disable Login", systemImage: "nosign")
            }
            .disabled(!(session.permissions?.canManageRoles ?? true))
        }

        Divider()

        // Group 9: Destructive
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
        .disabled(!(session.permissions?.canManageRoles ?? true))

        Divider()

        // Group 10: Properties — ALWAYS last
        Button {
            let value = environmentState.prepareLoginEditorWindow(
                connectionSessionID: session.connection.id,
                existingLogin: login.name
            )
            openWindow(id: LoginEditorWindow.sceneID, value: value)
        } label: {
            Label("Properties", systemImage: "info.circle")
        }
    }
}

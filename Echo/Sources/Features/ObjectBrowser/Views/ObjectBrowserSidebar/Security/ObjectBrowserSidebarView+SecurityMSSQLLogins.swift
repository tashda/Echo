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

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                depth: 1,
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
                    Label("New Login", systemImage: "plus")
                }
                Divider()
                Button {
                    loadServerSecurity(session: session)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if isExpanded {
                ForEach(standardLogins) { login in
                    loginRow(login: login, session: session)
                }

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

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                depth: 2,
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
                ForEach(certLogins) { login in
                    loginRow(login: login, session: session, depth: 3)
                }
            }
        }
    }

    func loginRow(login: ObjectBrowserSidebarViewModel.SecurityLoginItem, session: ConnectionSession, depth: Int = 2) -> some View {
        SidebarRow(
            depth: depth,
            icon: .system(login.isDisabled ? "person.crop.circle.badge.xmark" : "person.crop.circle"),
            label: login.name,
            iconColor: login.isDisabled ? ColorTokens.Text.quaternary : (projectStore.globalSettings.sidebarColoredIcons ? ExplorerSidebarPalette.security : ExplorerSidebarPalette.monochrome),
            labelColor: login.isDisabled ? ColorTokens.Text.secondary : ColorTokens.Text.primary
        ) {
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
            Label("Properties", systemImage: "info.circle")
        }
    }
}

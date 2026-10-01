import SwiftUI

extension MSSQLServerSecurityView {
    @ViewBuilder
    var sectionContent: some View {
        VStack(spacing: 0) {
            if !(session?.permissions?.canManageRoles ?? true) {
                PermissionBanner(message: "Some operations require the securityadmin or sysadmin role.")
            }

            if isCurrentSectionLoading {
                TabInitializingPlaceholder(
                    icon: "lock.shield",
                    title: "Loading Security",
                    subtitle: "Fetching \(viewModel.selectedSection.rawValue.lowercased())…"
                )
            } else if isCurrentSectionEmpty {
                emptyState
            } else {
                populatedSection
            }
        }
        .tabContentFrame()
    }

    @ViewBuilder
    private var populatedSection: some View {
        switch viewModel.selectedSection {
        case .logins:
            MSSQLSecurityLoginsSection(viewModel: viewModel)
        case .serverRoles:
            MSSQLSecurityServerRolesSection(viewModel: viewModel) { showNewRoleSheet = true }
        case .credentials:
            MSSQLSecurityCredentialsSection(viewModel: viewModel) { showNewCredentialSheet = true }
        case .audits:
            MSSQLSecurityAuditsSection(viewModel: viewModel) { showNewAuditSheet = true }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch viewModel.selectedSection {
        case .logins:
            TabContentUnavailableView("No Logins", systemImage: "person.crop.circle.badge.questionmark") {
                Text("No server logins were returned.")
            }
        case .serverRoles:
            TabContentUnavailableView("No Server Roles", systemImage: "shield") {
                Text("No server roles are configured.")
            } actions: {
                Button("New Server Role") { showNewRoleSheet = true }.buttonStyle(.bordered)
            }
        case .credentials:
            TabContentUnavailableView("No Credentials", systemImage: "key") {
                Text("No server credentials are configured.")
            } actions: {
                Button("New Credential") { showNewCredentialSheet = true }.buttonStyle(.bordered)
            }
        case .audits:
            TabContentUnavailableView("No Audits", systemImage: "checkmark.shield") {
                Text("No SQL Server audits are configured.")
            } actions: {
                Button("New Audit") { showNewAuditSheet = true }.buttonStyle(.bordered)
            }
        }
    }

    private var isCurrentSectionLoading: Bool {
        switch viewModel.selectedSection {
        case .logins: viewModel.isLoadingLogins
        case .serverRoles: viewModel.isLoadingServerRoles
        case .credentials: viewModel.isLoadingCredentials
        case .audits: viewModel.isLoadingAudits
        }
    }

    private var isCurrentSectionEmpty: Bool {
        switch viewModel.selectedSection {
        case .logins: viewModel.logins.isEmpty
        case .serverRoles: viewModel.serverRoles.isEmpty
        case .credentials: viewModel.credentials.isEmpty
        case .audits: viewModel.audits.isEmpty
        }
    }
}

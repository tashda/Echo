import SwiftUI

struct MySQLDatabaseSecurityView: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(\.workspaceTab) private var hostTab

    @State private var showNewUserSheet = false
    @State private var showNewRoleSheet = false
    @State private var showGrantPrivilegesSheet = false

    var body: some View {
        MaintenanceTabFrame(
            panelState: panelState,
            serverName: connectionText,
            isInitialized: viewModel.isInitialized,
            statusBubble: statusBubble
        ) {
            // Its pages are in the tab (round 36.2); its main action on the header line (37.2).
            VStack(spacing: 0) {
                switch viewModel.selectedSection {
                case .users:
                    MySQLSecurityUsersSection(viewModel: viewModel)
                case .roles:
                    MySQLSecurityRolesSection(viewModel: viewModel)
                case .privileges:
                    MySQLSecurityPrivilegesSection(viewModel: viewModel)
                case .advancedObjects:
                    MySQLAdvancedObjectsView(viewModel: viewModel)
                case .passwordPolicies:
                    MySQLPasswordPoliciesSection(viewModel: viewModel)
                case .dataMasking:
                    MySQLDataMaskingSection(viewModel: viewModel)
                case .encryption:
                    MySQLEncryptionSection(viewModel: viewModel)
                case .audit:
                    MySQLAuditSection(viewModel: viewModel)
                case .firewall:
                    MySQLFirewallSection(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolTabHeaderControls { primaryAction }
        .task {
            await viewModel.initialize()
        }
        .onChange(of: viewModel.selectedSection) { _, _ in
            guard viewModel.isInitialized else { return }
            Task { await viewModel.loadCurrentSection() }
        }
        .sheet(isPresented: $showNewUserSheet) {
            MySQLNewUserSheet(viewModel: viewModel) {
                showNewUserSheet = false
            }
        }
        .sheet(isPresented: $showNewRoleSheet) {
            MySQLNewRoleSheet(viewModel: viewModel) {
                showNewRoleSheet = false
            }
        }
        .sheet(isPresented: $showGrantPrivilegesSheet) {
            MySQLGrantPrivilegesSheet(
                databaseName: hostTab?.activeDatabaseName ?? hostTab?.connection.database ?? "",
                grantees: viewModel.privilegeGrantees
            ) { grantee, privileges, withGrantOption in
                let databaseName = hostTab?.activeDatabaseName ?? hostTab?.connection.database ?? ""
                Task {
                    await viewModel.grantSchemaPrivileges(
                        on: databaseName,
                        to: grantee,
                        privileges: privileges,
                        withGrantOption: withGrantOption
                    )
                }
            } onDismiss: {
                showGrantPrivilegesSheet = false
            }
        }
    }


    /// The page's main action (round 37.3, PA1): what you make on this page.
    @ViewBuilder
    private var primaryAction: some View {
        switch viewModel.selectedSection {
        case .users:
            ToolTabPrimaryButton(title: "New User", systemImage: "person.badge.plus") { showNewUserSheet = true }
        case .roles:
            ToolTabPrimaryButton(title: "New Role", systemImage: "person.2.badge.plus") { showNewRoleSheet = true }
        case .privileges:
            ToolTabPrimaryButton(title: "Grant", systemImage: "key.fill") { showGrantPrivilegesSheet = true }
        case .advancedObjects, .passwordPolicies, .dataMasking, .encryption, .audit, .firewall:
            EmptyView()
        }
    }
    private var connectionText: String {
        let connText = hostTab?.connection.connectionName ?? "Server"
        let db = hostTab?.activeDatabaseName
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingUsers || viewModel.isLoadingUserDetails || viewModel.isLoadingRoles || viewModel.isLoadingPrivileges {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }
}

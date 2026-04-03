import SwiftUI

struct MySQLDatabaseSecurityView: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore

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
            HStack(spacing: SpacingTokens.md) {
                Picker(selection: $viewModel.selectedSection) {
                    ForEach(MySQLDatabaseSecurityViewModel.Section.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 720)

                Spacer()

                switch viewModel.selectedSection {
                case .users:
                    Button { showNewUserSheet = true } label: {
                        Label("New User", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.borderless)
                case .roles:
                    Button { showNewRoleSheet = true } label: {
                        Label("New Role", systemImage: "person.2.badge.plus")
                    }
                    .buttonStyle(.borderless)
                case .privileges:
                    Button {
                        showGrantPrivilegesSheet = true
                    } label: {
                        Label("Grant…", systemImage: "key.fill")
                    }
                    .buttonStyle(.borderless)
                case .advancedObjects, .passwordPolicies, .dataMasking, .encryption, .audit, .firewall:
                    EmptyView()
                }
            }
        } content: {
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
                databaseName: tabStore.activeTab?.activeDatabaseName ?? tabStore.activeTab?.connection.database ?? "",
                grantees: viewModel.privilegeGrantees
            ) { grantee, privileges, withGrantOption in
                let databaseName = tabStore.activeTab?.activeDatabaseName ?? tabStore.activeTab?.connection.database ?? ""
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

    private var connectionText: String {
        let connText = tabStore.activeTab?.connection.connectionName ?? "Server"
        let db = tabStore.activeTab?.activeDatabaseName
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingUsers || viewModel.isLoadingUserDetails || viewModel.isLoadingRoles || viewModel.isLoadingPrivileges {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }
}

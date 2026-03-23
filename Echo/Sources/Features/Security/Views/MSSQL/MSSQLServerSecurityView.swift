import SwiftUI

struct MSSQLServerSecurityView: View {
    @Bindable var viewModel: ServerSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState

    @State private var showNewRoleSheet = false
    @State private var showNewCredentialSheet = false

    private var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

    var body: some View {
        MaintenanceTabFrame(
            panelState: panelState,
            connectionText: connectionText,
            isInitialized: viewModel.isInitialized,
            statusBubble: statusBubble
        ) {
            sectionPicker
        } content: {
            sectionContent
        }
        .task {
            await viewModel.loadInitialData()
        }
        .onChange(of: viewModel.selectedSection) { _, _ in
            guard viewModel.isInitialized else { return }
            Task { await viewModel.loadCurrentSection() }
        }
        .sheet(isPresented: $showNewRoleSheet) {
            if let session {
                NewServerRoleSheet(session: session) {
                    showNewRoleSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
        .sheet(isPresented: $showNewCredentialSheet) {
            if let session {
                NewCredentialSheet(session: session) {
                    showNewCredentialSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
    }

    private var connectionText: String {
        tabStore.activeTab?.connection.connectionName ?? "Server"
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingLogins || viewModel.isLoadingServerRoles || viewModel.isLoadingCredentials {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        Picker(selection: $viewModel.selectedSection) {
            ForEach(ServerSecurityViewModel.Section.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionContent: some View {
        VStack(spacing: 0) {
            if !(session?.permissions?.canManageRoles ?? true) {
                PermissionBanner(message: "Some operations require the securityadmin or sysadmin role.")
            }
            switch viewModel.selectedSection {
            case .logins:
                MSSQLSecurityLoginsSection(viewModel: viewModel)
            case .serverRoles:
                MSSQLSecurityServerRolesSection(
                    viewModel: viewModel,
                    onNewRole: { showNewRoleSheet = true }
                )
            case .credentials:
                MSSQLSecurityCredentialsSection(
                    viewModel: viewModel,
                    onNewCredential: { showNewCredentialSheet = true }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

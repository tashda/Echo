import SwiftUI

struct MSSQLServerSecurityView: View {
    @Bindable var viewModel: ServerSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState

    @State var showNewRoleSheet = false
    @State var showNewCredentialSheet = false
    @State var showNewAuditSheet = false

    var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

    var body: some View {
        MaintenanceTabFrame(
            panelState: panelState,
            serverName: connectionText,
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
        .sheet(isPresented: $showNewAuditSheet) {
            if let session {
                NewServerAuditSheet(session: session) {
                    showNewAuditSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
    }

    private var connectionText: String {
        tabStore.activeTab?.connection.connectionName ?? "Server"
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingLogins || viewModel.isLoadingServerRoles || viewModel.isLoadingCredentials || viewModel.isLoadingAudits {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        TabSectionPicker(
            "Security Section",
            selection: $viewModel.selectedSection,
            itemCount: ServerSecurityViewModel.Section.allCases.count
        ) {
            ForEach(ServerSecurityViewModel.Section.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        }
    }

}

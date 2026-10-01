import SwiftUI

struct MSSQLServerSecurityView: View {
    @Bindable var viewModel: ServerSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(\.workspaceTab) private var hostTab
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.openWindow) private var openWindow

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
            // Its pages are in the tab (round 36.2); each page's New is the special button in the
            // window toolbar (round 37.5, the owner's answer).
            sectionContent
        }
        .tabToolbar(special: newItem, groups: [[.refresh(isBusy: statusBubble != nil) { [viewModel] in
            Task { await viewModel.loadCurrentSection() }
        }]])
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

    /// The page's New (round 37.5): New Login opens its window, the others their sheets.
    private var newItem: TabToolbarItem {
        switch viewModel.selectedSection {
        case .logins:
            TabToolbarItem(id: "newLogin", title: "New Login", symbol: "person.badge.plus") { [environmentState, viewModel, openWindow] in
                let value = environmentState.prepareLoginEditorWindow(connectionSessionID: viewModel.connectionID, existingLogin: nil)
                openWindow(id: LoginEditorWindow.sceneID, value: value)
            }
        case .serverRoles:
            TabToolbarItem(id: "newServerRole", title: "New Server Role", symbol: "person.2.badge.plus") { showNewRoleSheet = true }
        case .credentials:
            TabToolbarItem(id: "newCredential", title: "New Credential", symbol: "key.fill") { showNewCredentialSheet = true }
        case .audits:
            TabToolbarItem(id: "newAudit", title: "New Audit", symbol: "plus") { showNewAuditSheet = true }
        }
    }

    private var connectionText: String {
        hostTab?.connection.connectionName ?? "Server"
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingLogins || viewModel.isLoadingServerRoles || viewModel.isLoadingCredentials || viewModel.isLoadingAudits {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }


}

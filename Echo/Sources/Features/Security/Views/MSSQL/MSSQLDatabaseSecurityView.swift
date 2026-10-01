import SwiftUI

struct MSSQLDatabaseSecurityView: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(\.workspaceTab) private var hostTab
    @Environment(EnvironmentState.self) var environmentState
    @Environment(\.openWindow) var openWindow

    @State var showNewRoleSheet = false
    @State var showNewSchemaSheet = false
    @State var showNewAppRoleSheet = false
    @State var showNewRLSPolicySheet = false
    @State var showNewMaskSheet = false
    @State var showNewAuditSpecSheet = false
    @State var showNewCMKSheet = false
    @State var showNewCEKSheet = false

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
            await viewModel.loadDatabases()
        }
        .onChange(of: viewModel.selectedSection) { _, _ in
            guard viewModel.isInitialized else { return }
            Task { await viewModel.loadCurrentSection() }
        }
        .onChange(of: viewModel.selectedDatabase) { _, newDB in
            guard let newDB else { return }
            if let tab = hostTab, tab.databaseSecurity != nil {
                tab.title = "Database Security (\(newDB))"
                tab.activeDatabaseName = newDB
            }
        }
        .sheet(isPresented: $showNewRoleSheet) {
            NewDatabaseRoleSheet(viewModel: viewModel) {
                showNewRoleSheet = false
                Task { await viewModel.loadCurrentSection() }
            }
        }
        .sheet(isPresented: $showNewSchemaSheet) {
            NewSchemaSheet(viewModel: viewModel) {
                showNewSchemaSheet = false
                Task { await viewModel.loadCurrentSection() }
            }
        }
        .sheet(isPresented: $showNewAppRoleSheet) {
            NewAppRoleSheet(viewModel: viewModel) {
                showNewAppRoleSheet = false
                Task { await viewModel.loadCurrentSection() }
            }
        }
        .sheet(isPresented: $showNewRLSPolicySheet) {
            NewRLSPolicySheet(viewModel: viewModel) {
                showNewRLSPolicySheet = false
                Task { await viewModel.loadCurrentSection() }
            }
        }
        .sheet(isPresented: $showNewMaskSheet) {
            if let session {
                NewMaskSheet(session: session, database: viewModel.selectedDatabase) {
                    showNewMaskSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
        .sheet(isPresented: $showNewAuditSpecSheet) {
            if let session {
                NewDBAuditSpecSheet(session: session, database: viewModel.selectedDatabase) {
                    showNewAuditSpecSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
        .sheet(isPresented: $showNewCMKSheet) {
            if let session {
                NewColumnMasterKeySheet(session: session, database: viewModel.selectedDatabase) {
                    showNewCMKSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
        .sheet(isPresented: $showNewCEKSheet) {
            if let session {
                NewColumnEncryptionKeySheet(session: session, database: viewModel.selectedDatabase) {
                    showNewCEKSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
    }

    private var connectionText: String {
        let connText = hostTab?.connection.connectionName ?? "Server"
        let db = viewModel.selectedDatabase
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingUsers || viewModel.isLoadingRoles ||
           viewModel.isLoadingAppRoles || viewModel.isLoadingSchemas ||
           viewModel.isLoadingCertificates || viewModel.isLoadingMaskedColumns ||
           viewModel.isLoadingSecurityPolicies || viewModel.isLoadingDBAuditSpecs ||
           viewModel.isLoadingAlwaysEncrypted {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }


}

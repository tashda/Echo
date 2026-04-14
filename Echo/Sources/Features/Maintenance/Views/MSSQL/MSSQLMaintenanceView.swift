import SwiftUI

struct MSSQLMaintenanceView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(ProjectStore.self) private var projectStore
    @Environment(EnvironmentState.self) private var environmentState

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
            Picker(selection: $viewModel.selectedSection) {
                ForEach(MSSQLMaintenanceViewModel.MaintenanceSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 440)
        } content: {
            sectionContent
        }
        .task {
            await viewModel.loadDatabases()
        }
        .onChange(of: panelState.messages.count) { _, _ in
            if !panelState.isOpen && projectStore.globalSettings.autoOpenBottomPanel {
                panelState.isOpen = true
            }
        }
        .onChange(of: viewModel.selectedDatabase) { _, newDB in
            guard let newDB else { return }
            if let tab = tabStore.activeTab, tab.mssqlMaintenance != nil {
                tab.title = "Maintenance (\(newDB))"
            }
        }
    }

    private var connectionText: String {
        let connText = tabStore.activeTab?.connection.connectionName ?? "Server"
        let db = viewModel.selectedDatabase
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isCheckingIntegrity {
            return .init(label: "Checking Integrity", tint: .orange, isPulsing: true)
        } else if viewModel.isShrinking {
            return .init(label: "Shrinking", tint: .orange, isPulsing: true)
        } else if viewModel.isRefreshingTables {
            return .init(label: "Loading Tables", tint: .blue, isPulsing: true)
        }
        return nil
    }

    @ViewBuilder
    private var sectionContent: some View {
        VStack(spacing: 0) {
            if !(session?.permissions?.canBackupRestore ?? true) {
                PermissionBanner(message: "Some operations require the sysadmin or db_backupoperator role.")
            }
            switch viewModel.selectedSection {
            case .health:
                MSSQLMaintenanceHealthView(viewModel: viewModel)
            case .tables:
                MSSQLMaintenanceTablesView(viewModel: viewModel)
            case .indexes:
                MSSQLMaintenanceIndexesView(viewModel: viewModel)
            case .backups:
                MSSQLMaintenanceBackupsView(viewModel: viewModel)
            case .queryStore:
                if let qsVM = viewModel.queryStoreVM {
                    QueryStoreView(viewModel: qsVM)
                } else {
                    ContentUnavailableView {
                        Label("Query Store Unavailable", systemImage: "chart.bar.xaxis")
                    } description: {
                        Text("Select a database to view Query Store data.")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

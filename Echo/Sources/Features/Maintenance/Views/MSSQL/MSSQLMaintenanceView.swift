import SwiftUI

struct MSSQLMaintenanceView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(AppState.self) private var appState
    @Environment(TabStore.self) private var tabStore
    @Environment(ProjectStore.self) private var projectStore

    var body: some View {
        TabContentWithPanel(
            panelState: panelState,
            statusBarConfiguration: statusBarConfig
        ) {
            mainBody
        } panelContent: {
            ExecutionConsoleView(executionMessages: panelState.messages) {
                panelState.clearMessages()
            }
        }
        .task {
            await viewModel.loadDatabases()
        }
        .onChange(of: viewModel.selectedSection) { _, _ in
            guard viewModel.isInitialized else { return }
            Task { await viewModel.loadCurrentSection() }
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

    private var statusBarConfig: BottomPanelStatusBarConfiguration {
        let connText = tabStore.activeTab?.connection.connectionName ?? "Server"
        let db = viewModel.selectedDatabase
        let text = db.map { "\(connText) • \($0)" } ?? connText

        var config = BottomPanelStatusBarConfiguration(
            connectionText: text,
            availableSegments: panelState.availableSegments,
            selectedSegment: panelState.selectedSegment,
            onSelectSegment: { segment in
                if panelState.isOpen && panelState.selectedSegment == segment {
                    panelState.isOpen = false
                } else {
                    panelState.selectedSegment = segment
                    if !panelState.isOpen { panelState.isOpen = true }
                }
            },
            onTogglePanel: { panelState.isOpen.toggle() },
            isPanelOpen: panelState.isOpen
        )

        if viewModel.isCheckingIntegrity {
            config.statusBubble = .init(label: "Checking Integrity", tint: .orange, isPulsing: true)
        } else if viewModel.isShrinking {
            config.statusBubble = .init(label: "Shrinking", tint: .orange, isPulsing: true)
        } else if viewModel.isRefreshingTables {
            config.statusBubble = .init(label: "Loading Tables", tint: .blue, isPulsing: true)
        }

        return config
    }

    @ViewBuilder
    private var mainBody: some View {
        if !viewModel.isInitialized {
            TabInitializingPlaceholder(
                icon: "wrench.and.screwdriver",
                title: "Initializing Maintenance",
                subtitle: "Loading database health data\u{2026}"
            )
        } else {
            VStack(spacing: 0) {
                sectionToolbar
                Divider()
                maintenanceContent
            }
        }
    }

    private var sectionToolbar: some View {
        MaintenanceToolbar {
            Picker(selection: $viewModel.selectedSection) {
                ForEach(MSSQLMaintenanceViewModel.MaintenanceSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)
        }
    }

    @ViewBuilder
    private var maintenanceContent: some View {
        VStack(spacing: 0) {
            switch viewModel.selectedSection {
            case .health:
                MSSQLMaintenanceHealthView(viewModel: viewModel)
            case .tables:
                MSSQLMaintenanceTablesView(viewModel: viewModel)
            case .indexes:
                MSSQLMaintenanceIndexesView(viewModel: viewModel)
            case .backups:
                MSSQLMaintenanceBackupsView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

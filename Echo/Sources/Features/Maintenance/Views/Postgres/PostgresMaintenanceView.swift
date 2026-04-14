import SwiftUI

struct PostgresMaintenanceView: View {
    @Bindable var viewModel: MaintenanceViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(EnvironmentState.self) var environmentState
    @Environment(TabStore.self) private var tabStore
    @Environment(AppState.self) var appState
    @Environment(ProjectStore.self) private var projectStore

    @State private var selectedSection: PostgresMaintenanceSection = .health

    @State private var tableStatsSortOrder = [KeyPathComparator(\PostgresMaintenanceTableStat.nDeadTup, order: .reverse)]
    @State private var indexStatsSortOrder = [KeyPathComparator(\PostgresIndexStat.idxScan)]

    @State private var selectedTableIDs: Set<PostgresMaintenanceTableStat.ID> = []
    @State private var selectedIndexIDs: Set<PostgresIndexStat.ID> = []

    enum PostgresMaintenanceSection: String, CaseIterable {
        case health = "Health"
        case tables = "Tables"
        case indexes = "Indexes"
    }

    var body: some View {
        MaintenanceTabFrame(
            panelState: panelState,
            connectionText: connectionText,
            isInitialized: viewModel.isInitialized,
            statusBubble: statusBubble
        ) {
            Picker(selection: $selectedSection) {
                ForEach(PostgresMaintenanceSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        } content: {
            sectionContent
        }
        .task(id: viewModel.connectionSessionID) {
            viewModel.pgBackupsVM?.panelState = panelState
            await loadDatabases()
            if let db = viewModel.selectedDatabase {
                await loadData(for: db)
            }
            viewModel.isInitialized = true
        }
        .onChange(of: viewModel.selectedDatabase) { _, newDB in
            guard let newDB else { return }
            selectedTableIDs.removeAll()
            selectedIndexIDs.removeAll()
            environmentState.dataInspectorContent = nil
            if let tab = tabStore.activeTab, tab.maintenance != nil {
                tab.title = "Maintenance (\(newDB))"
            }
            Task { await loadData(for: newDB) }
        }
        .onChange(of: selectedSection) { _, _ in
            environmentState.dataInspectorContent = nil
            guard let db = viewModel.selectedDatabase else { return }
            Task { await loadSectionData(for: db) }
        }
        .onChange(of: panelState.messages.count) { _, _ in
            if !panelState.isOpen && projectStore.globalSettings.autoOpenBottomPanel {
                panelState.isOpen = true
            }
        }
        .onAppear {
            if let sectionName = viewModel.requestedSection,
               let section = PostgresMaintenanceSection(rawValue: sectionName) {
                selectedSection = section
                viewModel.requestedSection = nil
            }
        }
        .onChange(of: viewModel.requestedSection) { _, newSection in
            if let sectionName = newSection,
               let section = PostgresMaintenanceSection(rawValue: sectionName) {
                selectedSection = section
                viewModel.requestedSection = nil
            }
        }
        .onChange(of: selectedTableIDs) { _, newIDs in
            pushTableInspector(ids: newIDs)
        }
        .onChange(of: selectedIndexIDs) { _, newIDs in
            pushIndexInspector(ids: newIDs)
        }
    }

    // MARK: - Computed Properties

    private var connectionText: String {
        let connText = tabStore.activeTab?.connection.connectionName ?? "Server"
        let db = viewModel.selectedDatabase
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingHealth {
            return .init(label: "Loading Health", tint: .blue, isPulsing: true)
        } else if viewModel.isLoadingTables {
            return .init(label: "Loading Tables", tint: .blue, isPulsing: true)
        } else if viewModel.isLoadingIndexes {
            return .init(label: "Loading Indexes", tint: .blue, isPulsing: true)
        }
        return nil
    }

    // MARK: - Section Content

    private var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

    @ViewBuilder
    private var sectionContent: some View {
        if !(session?.permissions?.canVacuumFull ?? true) {
            PermissionBanner(message: "Some operations require the superuser role.")
        }
        switch selectedSection {
        case .health:
            PostgresMaintenanceHealthView(viewModel: viewModel)
        case .tables:
            PostgresMaintenanceTables(
                viewModel: viewModel,
                sortOrder: $tableStatsSortOrder,
                selection: $selectedTableIDs
            )
        case .indexes:
            PostgresMaintenanceIndexes(
                viewModel: viewModel,
                sortOrder: $indexStatsSortOrder,
                selection: $selectedIndexIDs
            )
        }
    }

    // MARK: - Data Loading

    private func loadData(for database: String) async {
        await viewModel.fetchHealth(for: database)
        await viewModel.fetchTableStats(for: database)
        await viewModel.fetchIndexStats(for: database)
    }

    private func loadSectionData(for database: String) async {
        switch selectedSection {
        case .health:
            await viewModel.fetchHealth(for: database)
        case .tables:
            await viewModel.fetchTableStats(for: database)
        case .indexes:
            await viewModel.fetchIndexStats(for: database)
        }
    }

    private func loadDatabases() async {
        guard let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) else { return }
        let databases = session.databaseStructure?.databases.map(\.name).sorted() ?? []
        viewModel.databaseList = databases
        if viewModel.selectedDatabase == nil, let first = databases.first {
            viewModel.selectedDatabase = first
        }
    }
}

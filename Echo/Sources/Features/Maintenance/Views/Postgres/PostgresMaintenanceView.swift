import SwiftUI
import PostgresWire

struct PostgresMaintenanceView: View {
    @Bindable var viewModel: MaintenanceViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(TabStore.self) private var tabStore
    @Environment(AppState.self) private var appState

    @State private var selectedSection: PostgresMaintenanceSection = .tables
    @State private var availableDatabases: [String] = []

    @State private var tableStatsSortOrder = [KeyPathComparator(\PostgresTableStat.nDeadTup, order: .reverse)]
    @State private var indexStatsSortOrder = [KeyPathComparator(\PostgresIndexStat.idxScan)]

    @State private var selectedTableIDs: Set<PostgresTableStat.ID> = []
    @State private var selectedIndexIDs: Set<PostgresIndexStat.ID> = []

    enum PostgresMaintenanceSection: String, CaseIterable {
        case tables = "Tables"
        case indexes = "Indexes"
    }

    var body: some View {
        VStack(spacing: 0) {
            MaintenanceToolbar(
                databases: availableDatabases,
                selectedDatabase: $viewModel.selectedDatabase
            ) {
                Picker(selection: $selectedSection) {
                    ForEach(PostgresMaintenanceSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            Divider()

            if !viewModel.isInitialized {
                TabInitializingPlaceholder(
                    icon: "wrench.and.screwdriver",
                    title: "Initializing Maintenance",
                    subtitle: "Loading database health data\u{2026}"
                )
            } else {
                sectionContent
            }
        }
        .background(ColorTokens.Background.primary)
        .task(id: viewModel.connectionSessionID) {
            await loadDatabases()
            viewModel.isInitialized = true
            if let db = viewModel.selectedDatabase {
                await loadData(for: db)
            }
        }
        .onChange(of: viewModel.selectedDatabase) { _, newDB in
            guard let newDB else { return }
            selectedTableIDs.removeAll()
            selectedIndexIDs.removeAll()
            environmentState.dataInspectorContent = nil
            // Update tab title to reflect selected database
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
        .onChange(of: selectedTableIDs) { _, newIDs in
            pushTableInspector(ids: newIDs)
        }
        .onChange(of: selectedIndexIDs) { _, newIDs in
            pushIndexInspector(ids: newIDs)
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
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

    // MARK: - Inspector Integration

    private func pushTableInspector(ids: Set<PostgresTableStat.ID>) {
        guard let id = ids.first,
              let table = viewModel.tableStats.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let deadRatio = table.nLiveTup > 0 ? String(format: "%.1f%%", Double(table.nDeadTup) / Double(table.nLiveTup) * 100) : "N/A"
        let fields: [ForeignKeyInspectorContent.Field] = [
            .init(label: "Schema", value: table.schemaName),
            .init(label: "Table", value: table.tableName),
            .init(label: "Live Tuples", value: formatCount(table.nLiveTup)),
            .init(label: "Dead Tuples", value: formatCount(table.nDeadTup)),
            .init(label: "Dead Ratio", value: deadRatio),
            .init(label: "Sequential Scans", value: formatCount(table.seqScan)),
            .init(label: "Index Scans", value: formatCount(table.idxScan)),
            .init(label: "Seq Tuples Read", value: formatCount(table.seqTupRead)),
            .init(label: "Idx Tuples Fetched", value: formatCount(table.idxTupFetch)),
            .init(label: "Last Vacuum", value: formatDate(manual: table.lastVacuum, auto: table.lastAutoVacuum)),
            .init(label: "Last Analyze", value: formatDate(manual: table.lastAnalyze, auto: table.lastAutoAnalyze))
        ]
        environmentState.dataInspectorContent = .foreignKey(ForeignKeyInspectorContent(
            title: table.tableName,
            subtitle: "Table \u{2022} \(table.schemaName)",
            fields: fields
        ))
    }

    private func pushIndexInspector(ids: Set<PostgresIndexStat.ID>) {
        guard let id = ids.first,
              let index = viewModel.indexStats.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let kindLabel = index.isPrimary ? "Primary Key" : index.isUnique ? "Unique" : "Index"
        let fields: [ForeignKeyInspectorContent.Field] = [
            .init(label: "Index", value: index.indexName),
            .init(label: "Table", value: "\(index.schemaName).\(index.tableName)"),
            .init(label: "Kind", value: kindLabel),
            .init(label: "Type", value: index.indexType),
            .init(label: "Valid", value: index.isValid ? "Yes" : "No"),
            .init(label: "Index Size", value: ByteCountFormatter.string(fromByteCount: index.indexSizeBytes, countStyle: .binary)),
            .init(label: "Table Size", value: ByteCountFormatter.string(fromByteCount: index.tableSizeBytes, countStyle: .binary)),
            .init(label: "Index/Table Ratio", value: String(format: "%.0f%%", index.indexToTablePct)),
            .init(label: "Scans", value: formatCount(index.idxScan)),
            .init(label: "Tuples Read", value: formatCount(index.idxTupRead)),
            .init(label: "Tuples Fetched", value: formatCount(index.idxTupFetch)),
            .init(label: "Definition", value: index.definition)
        ]
        environmentState.dataInspectorContent = .foreignKey(ForeignKeyInspectorContent(
            title: index.indexName,
            subtitle: "\(kindLabel) \u{2022} \(index.indexType)",
            fields: fields
        ))
    }

    // MARK: - Helpers

    private func formatCount(_ count: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func formatDate(manual: Date?, auto: Date?) -> String {
        let latest: Date? = switch (manual, auto) {
        case let (m?, a?): max(m, a)
        case let (m?, nil): m
        case let (nil, a?): a
        case (nil, nil): nil
        }
        guard let date = latest else { return "Never" }
        let isAuto = auto != nil && (manual == nil || auto! >= manual!)
        let relative = date.formatted(.relative(presentation: .named))
        return "\(relative) (\(isAuto ? "auto" : "manual"))"
    }

    private func refreshCurrentSection() {
        guard let db = viewModel.selectedDatabase else { return }
        Task { await loadSectionData(for: db) }
    }

    private func loadData(for database: String) async {
        await viewModel.fetchTableStats(for: database)
        await viewModel.fetchIndexStats(for: database)
    }

    private func loadSectionData(for database: String) async {
        switch selectedSection {
        case .tables:
            await viewModel.fetchTableStats(for: database)
        case .indexes:
            await viewModel.fetchIndexStats(for: database)
        }
    }

    private func loadDatabases() async {
        guard let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) else { return }
        let databases = session.databaseStructure?.databases.map(\.name).sorted() ?? []
        availableDatabases = databases
        if viewModel.selectedDatabase == nil, let first = databases.first {
            viewModel.selectedDatabase = first
        }
    }
}

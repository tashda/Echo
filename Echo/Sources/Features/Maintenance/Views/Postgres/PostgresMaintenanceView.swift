import SwiftUI

struct PostgresMaintenanceView: View {
    @Bindable var viewModel: MaintenanceViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(TabStore.self) private var tabStore
    @Environment(AppState.self) private var appState

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
        VStack(spacing: 0) {
            MaintenanceToolbar {
                Picker(selection: $selectedSection) {
                    ForEach(PostgresMaintenanceSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
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

    // MARK: - Inspector Integration

    private func pushTableInspector(ids: Set<PostgresMaintenanceTableStat.ID>, toggle: Bool = false) {
        guard let id = ids.first,
              let table = viewModel.tableStats.first(where: { $0.id == id }) else {
            if !toggle { environmentState.dataInspectorContent = nil }
            return
        }
        let deadRatio = table.nLiveTup > 0 ? String(format: "%.1f%%", Double(table.nDeadTup) / Double(table.nLiveTup) * 100) : "N/A"
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Schema", value: table.schemaName),
            .init(label: "Table", value: table.tableName),
            .init(label: "Table Size", value: ByteCountFormatter.string(fromByteCount: table.tableSizeBytes, countStyle: .binary)),
            .init(label: "Index Size", value: ByteCountFormatter.string(fromByteCount: table.indexSizeBytes, countStyle: .binary)),
            .init(label: "Total Size", value: ByteCountFormatter.string(fromByteCount: table.totalSizeBytes, countStyle: .binary)),
            .init(label: "Live Tuples", value: formatCount(table.nLiveTup)),
            .init(label: "Dead Tuples", value: formatCount(table.nDeadTup)),
            .init(label: "Dead Ratio", value: deadRatio),
            .init(label: "Table Age (XID)", value: formatCount(table.tableAge)),
            .init(label: "Sequential Scans", value: formatCount(table.seqScan)),
            .init(label: "Index Scans", value: formatCount(table.idxScan)),
            .init(label: "Seq Tuples Read", value: formatCount(table.seqTupRead)),
            .init(label: "Idx Tuples Fetched", value: formatCount(table.idxTupFetch)),
            .init(label: "Last Vacuum", value: formatDate(manual: table.lastVacuum, auto: table.lastAutoVacuum)),
            .init(label: "Last Analyze", value: formatDate(manual: table.lastAnalyze, auto: table.lastAutoAnalyze))
        ]

        let content = DatabaseObjectInspectorContent(
            title: table.tableName,
            subtitle: "Table \u{2022} \(table.schemaName)",
            fields: fields
        )

        if toggle {
            environmentState.toggleDataInspector(content: .databaseObject(content), title: table.tableName, appState: appState)
        } else {
            environmentState.dataInspectorContent = .databaseObject(content)
        }
    }

    private func pushIndexInspector(ids: Set<PostgresIndexStat.ID>, toggle: Bool = false) {
        guard let id = ids.first,
              let index = viewModel.indexStats.first(where: { $0.id == id }) else {
            if !toggle { environmentState.dataInspectorContent = nil }
            return
        }
        let kindLabel = index.isPrimary ? "Primary Key" : index.isUnique ? "Unique" : "Index"
        let fields: [DatabaseObjectInspectorContent.Field] = [
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

        let content = DatabaseObjectInspectorContent(
            title: index.indexName,
            subtitle: "\(kindLabel) \u{2022} \(index.indexType)",
            fields: fields
        )

        if toggle {
            environmentState.toggleDataInspector(content: .databaseObject(content), title: index.indexName, appState: appState)
        } else {
            environmentState.dataInspectorContent = .databaseObject(content)
        }
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

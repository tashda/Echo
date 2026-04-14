import SwiftUI

struct PostgresMaintenanceTables: View {
    var viewModel: MaintenanceViewModel
    @Binding var sortOrder: [KeyPathComparator<PostgresMaintenanceTableStat>]
    @Binding var selection: Set<PostgresMaintenanceTableStat.ID>
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    @State private var vacuumFullTarget: PostgresMaintenanceTableStat?

    private var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

    var body: some View {
        Group {
            if viewModel.isLoadingTables && viewModel.tableStats.isEmpty {
                loadingView
            } else if viewModel.tableStats.isEmpty {
                ContentUnavailableView {
                    Label("No Table Statistics", systemImage: "tablecells")
                } description: {
                    Text("No user tables found in the selected database.")
                }
            } else {
                tableView
            }
        }
        .alert(
            "Vacuum Full",
            isPresented: Binding(
                get: { vacuumFullTarget != nil },
                set: { if !$0 { vacuumFullTarget = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { vacuumFullTarget = nil }
            Button("Vacuum Full", role: .destructive) {
                guard let table = vacuumFullTarget else { return }
                vacuumFullTarget = nil
                let database = viewModel.selectedDatabase ?? ""
                Task {
                    do {
                        try await viewModel.vacuumTable(database: database, schema: table.schemaName, table: table.tableName, full: true)
                        environmentState.notificationEngine?.post(.vacuumFullCompleted(schema: table.schemaName, table: table.tableName))
                    } catch {
                        environmentState.notificationEngine?.post(.maintenanceFailed(operation: "Vacuum Full", reason: error.localizedDescription))
                    }
                    if let db = viewModel.selectedDatabase {
                        await viewModel.fetchTableStats(for: db)
                    }
                }
            }
        } message: {
            if let table = vacuumFullTarget {
                Text("This will rewrite \(table.schemaName).\(table.tableName) and take an exclusive lock, blocking all reads and writes until complete.")
            }
        }
    }

    private var loadingView: some View {
        TabInitializingPlaceholder(
            icon: "tablecells",
            title: "Loading Tables",
            subtitle: "Fetching table statistics\u{2026}"
        )
    }

    private var tableView: some View {
        Table(viewModel.tableStats, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Table") {
                Text("\($0.schemaName).\($0.tableName)")
                    .font(TypographyTokens.Table.name)
                    .lineLimit(1)
            }.width(min: 140, ideal: 200)

            TableColumn("Size", value: \.totalSizeBytes) {
                Text(ByteCountFormatter.string(fromByteCount: $0.totalSizeBytes, countStyle: .binary))
                    .font(TypographyTokens.Table.numeric)
            }.width(min: 60, ideal: 75)

            TableColumn("Seq Scans", value: \.seqScan) {
                Text("\($0.seqScan)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle($0.seqScan > 1000 && $0.idxScan == 0 ? ColorTokens.Status.warning : ColorTokens.Text.primary)
            }.width(min: 70, ideal: 80)

            TableColumn("Idx Scans", value: \.idxScan) {
                Text("\($0.idxScan)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Status.success)
            }.width(min: 70, ideal: 80)

            TableColumn("Live", value: \.nLiveTup) {
                Text(formatCount($0.nLiveTup)).font(TypographyTokens.Table.numeric)
            }.width(min: 60, ideal: 70)

            TableColumn("Dead", value: \.nDeadTup) {
                Text(formatCount($0.nDeadTup))
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(deadTupleColor(dead: $0.nDeadTup, live: $0.nLiveTup))
            }.width(min: 60, ideal: 70)

            TableColumn("Age", value: \.tableAge) {
                Text(formatAge($0.tableAge))
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle($0.isAgingRisk ? ColorTokens.Status.error : ColorTokens.Text.secondary)
                    .help("Transaction ID age — risk above 500M (wraparound at 2B)")
            }.width(min: 60, ideal: 70)

            TableColumn("Last Vacuum") {
                MaintenanceDateCell(manual: $0.lastVacuum, auto: $0.lastAutoVacuum)
            }.width(min: 100, ideal: 130)

            TableColumn("Last Analyze") {
                MaintenanceDateCell(manual: $0.lastAnalyze, auto: $0.lastAutoAnalyze)
            }.width(min: 100, ideal: 130)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .onChange(of: sortOrder) { _, newOrder in
            viewModel.tableStats.sort(using: newOrder)
        }
        .onChange(of: viewModel.isLoadingTables) { old, new in
            if old && !new {
                viewModel.tableStats.sort(using: sortOrder)
            }
        }
        .contextMenu(forSelectionType: PostgresMaintenanceTableStat.ID.self) { ids in
            let tables = ids.compactMap { id in viewModel.tableStats.first(where: { $0.id == id }) }
            if !tables.isEmpty {
                tableContextMenu(for: tables)
            }
        } primaryAction: { _ in
            appState.showInfoSidebar.toggle()
        }
    }

    @ViewBuilder
    private func tableContextMenu(for tables: [PostgresMaintenanceTableStat]) -> some View {
        let countSuffix = tables.count > 1 ? " (\(tables.count))" : ""

        Button("Analyze\(countSuffix)") {
            runMaintenanceOnAll(tables: tables, operation: "Analyze") { db, table in
                try await viewModel.analyzeTable(database: db, schema: table.schemaName, table: table.tableName)
                return .analyzeCompleted(schema: table.schemaName, table: table.tableName)
            }
        }

        Button("Reindex\(countSuffix)") {
            runMaintenanceOnAll(tables: tables, operation: "Reindex") { db, table in
                try await viewModel.reindexTable(database: db, schema: table.schemaName, table: table.tableName)
                return .reindexCompleted(schema: table.schemaName, table: table.tableName)
            }
        }
        .disabled(!(session?.permissions?.canVacuumFull ?? true))

        Divider()

        Menu("Vacuum\(countSuffix)") {
            Button("Vacuum") {
                runMaintenanceOnAll(tables: tables, operation: "Vacuum") { db, table in
                    try await viewModel.vacuumTable(database: db, schema: table.schemaName, table: table.tableName)
                    return .vacuumCompleted(schema: table.schemaName, table: table.tableName)
                }
            }

            Button("Vacuum Analyze") {
                runMaintenanceOnAll(tables: tables, operation: "Vacuum Analyze") { db, table in
                    try await viewModel.vacuumTable(database: db, schema: table.schemaName, table: table.tableName, analyze: true)
                    return .vacuumAnalyzeCompleted(schema: table.schemaName, table: table.tableName)
                }
            }

            if tables.count == 1, let table = tables.first {
                Divider()

                Button("Vacuum Full") {
                    vacuumFullTarget = table
                }
                .disabled(!(session?.permissions?.canVacuumFull ?? true))
            }
        }
    }

    private func runMaintenanceOnAll(tables: [PostgresMaintenanceTableStat], operation: String, action: @escaping (String, PostgresMaintenanceTableStat) async throws -> NotificationEvent) {
        let database = viewModel.selectedDatabase ?? ""
        Task {
            for table in tables {
                do {
                    let event = try await action(database, table)
                    environmentState.notificationEngine?.post(event)
                } catch {
                    environmentState.notificationEngine?.post(.maintenanceFailed(operation: "\(operation) on \(table.schemaName).\(table.tableName)", reason: error.localizedDescription))
                }
            }
            if let db = viewModel.selectedDatabase {
                await viewModel.fetchTableStats(for: db)
            }
        }
    }

    private func formatCount(_ count: Int64) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private func formatAge(_ age: Int64) -> String {
        if age >= 1_000_000_000 { return String(format: "%.1fB", Double(age) / 1_000_000_000) }
        if age >= 1_000_000 { return String(format: "%.0fM", Double(age) / 1_000_000) }
        if age >= 1_000 { return String(format: "%.0fK", Double(age) / 1_000) }
        return "\(age)"
    }

    private func deadTupleColor(dead: Int64, live: Int64) -> Color {
        guard dead > 0 else { return ColorTokens.Text.quaternary }
        let ratio = live > 0 ? Double(dead) / Double(live) : 1.0
        if ratio > 0.2 { return ColorTokens.Status.error }
        if ratio > 0.05 { return ColorTokens.Status.warning }
        return ColorTokens.Text.primary
    }
}

struct MaintenanceDateCell: View {
    let manual: Date?
    let auto: Date?

    private var latest: Date? {
        switch (manual, auto) {
        case let (m?, a?): return max(m, a)
        case let (m?, nil): return m
        case let (nil, a?): return a
        case (nil, nil): return nil
        }
    }

    var body: some View {
        if let date = latest {
            Text(date, style: .relative)
                .font(TypographyTokens.Table.date)
                .foregroundStyle(isStale(date) ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
        } else {
            Text("\u{2014}")
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    private func isStale(_ date: Date) -> Bool {
        date.timeIntervalSinceNow < -86400 * 7
    }
}

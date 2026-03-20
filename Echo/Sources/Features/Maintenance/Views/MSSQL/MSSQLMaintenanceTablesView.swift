import SwiftUI

struct MSSQLMaintenanceTablesView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    @State private var sortOrder = [KeyPathComparator(\SQLServerTableStat.rowCount, order: .reverse)]
    @State private var selection: Set<SQLServerTableStat.ID> = []

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isRefreshingTables && viewModel.tableStats.isEmpty {
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
            TableColumn("Type", value: \.tableType) { table in
                Text(table.isHeap ? "Heap" : "CI")
                    .font(TypographyTokens.Table.kindBadge)
                    .foregroundStyle(table.isHeap ? .orange : ColorTokens.Text.tertiary)
            }
            .width(40)

            TableColumn("Table", value: \.tableName) { table in
                Text("\(table.schemaName).\(table.tableName)")
                    .font(TypographyTokens.Table.name)
                    .lineLimit(1)
            }

            TableColumn("Rows", value: \.rowCount) { table in
                Text(formatCount(table.rowCount))
                    .font(TypographyTokens.Table.numeric)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Data", value: \.dataSpaceKB) { table in
                Text(ByteCountFormatter.string(fromByteCount: table.dataSpaceBytes, countStyle: .binary))
                    .font(TypographyTokens.Table.numeric)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Indexes", value: \.indexSpaceKB) { table in
                Text(ByteCountFormatter.string(fromByteCount: table.indexSpaceBytes, countStyle: .binary))
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Unused", value: \.unusedSpaceKB) { table in
                Text(ByteCountFormatter.string(fromByteCount: table.unusedSpaceBytes, countStyle: .binary))
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(table.unusedRatio > 30 ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Total", value: \.totalSpaceKB) { table in
                Text(ByteCountFormatter.string(fromByteCount: table.totalSpaceBytes, countStyle: .binary))
                    .font(TypographyTokens.Table.numeric)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Stats Updated", value: \.lastStatsUpdateSort) { table in
                if let date = table.lastStatsUpdate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 100, ideal: 130)

            TableColumn("Status", value: \.status) { table in
                statusBadge(for: table)
            }
            .width(min: 80, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .onChange(of: sortOrder) { _, newOrder in
            viewModel.tableStats.sort(using: newOrder)
        }
        .onChange(of: viewModel.isRefreshingTables) { old, new in
            if old && !new {
                viewModel.tableStats.sort(using: sortOrder)
            }
        }
        .contextMenu(forSelectionType: SQLServerTableStat.ID.self) { ids in
            if let id = ids.first, let table = viewModel.tableStats.first(where: { $0.id == id }) {
                tableContextMenu(for: table)
            }
        } primaryAction: { _ in
            if let id = selection.first, let table = viewModel.tableStats.first(where: { $0.id == id }) {
                pushTableInspector(table, toggle: true)
            }
        }
        .onChange(of: selection) { _, newSelection in
            if let id = newSelection.first, let table = viewModel.tableStats.first(where: { $0.id == id }) {
                pushTableInspector(table, toggle: false)
            }
        }
    }

    private func statusBadge(for table: SQLServerTableStat) -> some View {
        let label = table.status
        let color: Color = switch label {
        case "Healthy": ColorTokens.Status.success
        case "Forwarded": ColorTokens.Status.warning
        case "Wasted Space": ColorTokens.Status.warning
        default: ColorTokens.Text.tertiary
        }

        return Text(label)
            .font(TypographyTokens.Table.status)
            .foregroundStyle(color)
    }

    @ViewBuilder
    private func tableContextMenu(for table: SQLServerTableStat) -> some View {
        Button {
            Task { await viewModel.updateTableStats(table) }
        } label: {
            Label("Update Statistics", systemImage: "chart.bar")
        }

        Button {
            Task { await viewModel.checkTable(table) }
        } label: {
            Label("Check Table", systemImage: "checkmark.shield")
        }

        Button {
            Task { await viewModel.rebuildAllIndexes(table) }
        } label: {
            Label("Rebuild All Indexes", systemImage: "hammer")
        }

        Button {
            Task { await viewModel.reorganizeAllIndexes(table) }
        } label: {
            Label("Reorganize All Indexes", systemImage: "arrow.triangle.2.circlepath")
        }

        Divider()

        Button {
            Task { await viewModel.rebuildTable(table) }
        } label: {
            Label("Rebuild Table", systemImage: "arrow.clockwise")
        }

        Divider()

        Button {
            openStructure(for: table)
        } label: {
            Label("View Structure", systemImage: "tablecells")
        }
    }

    private func pushTableInspector(_ table: SQLServerTableStat, toggle: Bool) {
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Schema", value: table.schemaName),
            .init(label: "Table", value: table.tableName),
            .init(label: "Type", value: table.tableType),
            .init(label: "Rows", value: formatCount(table.rowCount)),
            .init(label: "Data Size", value: ByteCountFormatter.string(fromByteCount: table.dataSpaceBytes, countStyle: .binary)),
            .init(label: "Index Size", value: ByteCountFormatter.string(fromByteCount: table.indexSpaceBytes, countStyle: .binary)),
            .init(label: "Unused Space", value: ByteCountFormatter.string(fromByteCount: table.unusedSpaceBytes, countStyle: .binary)),
            .init(label: "Total Size", value: ByteCountFormatter.string(fromByteCount: table.totalSpaceBytes, countStyle: .binary)),
            .init(label: "Stats Updated", value: table.lastStatsUpdate?.formatted(date: .abbreviated, time: .shortened) ?? "\u{2014}")
        ]

        let content = DatabaseObjectInspectorContent(
            title: table.tableName,
            subtitle: "\(table.tableType) \u{2022} \(table.schemaName)",
            fields: fields
        )

        if toggle {
            environmentState.toggleDataInspector(content: .databaseObject(content), title: table.tableName, appState: appState)
        } else {
            environmentState.dataInspectorContent = .databaseObject(content)
        }
    }

    private func openStructure(for table: SQLServerTableStat) {
        guard let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) else { return }

        let object = SchemaObjectInfo(
            name: table.tableName,
            schema: table.schemaName,
            type: .table
        )

        environmentState.openStructureTab(
            for: session,
            object: object,
            databaseName: viewModel.selectedDatabase
        )
    }

    private func formatCount(_ count: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}

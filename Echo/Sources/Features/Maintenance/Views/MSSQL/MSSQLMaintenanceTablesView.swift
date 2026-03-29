import SwiftUI

struct MSSQLMaintenanceTablesView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState

    @State private var sortOrder = [KeyPathComparator(\SQLServerTableStat.rowCount, order: .reverse)]
    @State private var selection: Set<SQLServerTableStat.ID> = []

    var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

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
        .tableColumnAutoResize()
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

    func statusBadge(for table: SQLServerTableStat) -> some View {
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
}

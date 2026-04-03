import SwiftUI
import SQLServerKit

struct QueryStoreTopQueriesSection: View {
    @Bindable var viewModel: QueryStoreViewModel
    var onPopout: ((String) -> Void)?
    var onOpenInQueryWindow: ((_ sql: String, _ database: String?) -> Void)?
    var onDoubleClick: (() -> Void)?
    @State private var sortOrder = [
        KeyPathComparator(\SQLServerQueryStoreTopQuery.totalDurationUs, order: .reverse)
    ]

    var body: some View {
        Table(sortedQueries, selection: $viewModel.selectedQueryId, sortOrder: $sortOrder) {
                TableColumn("ID", value: \.queryId) { query in
                    Text("\(query.queryId)")
                        .font(TypographyTokens.Table.numeric)
                }
                .width(min: 40, ideal: 55, max: 70)

                TableColumn("Query Text", value: \.queryText) { query in
                    SQLQueryCell(
                        sql: query.queryText,
                        databaseName: viewModel.databaseName,
                        onPopout: { sql in onPopout?(sql) },
                        onOpenInQueryWindow: onOpenInQueryWindow
                    )
                }
                .width(min: 250, ideal: 500)

                TableColumn("Executions", value: \.totalExecutions) { query in
                    Text(formatCount(query.totalExecutions))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 90, max: 110)

                TableColumn("Total Duration", value: \.totalDurationUs) { query in
                    Text(formatDuration(query.totalDurationUs))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 80, ideal: 110, max: 130)

                TableColumn("Total CPU", value: \.totalCPUUs) { query in
                    Text(formatDuration(query.totalCPUUs))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 80, ideal: 100, max: 120)

                TableColumn("Total I/O", value: \.totalIOReads) { query in
                    Text(formatCount(Int(query.totalIOReads)))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 90, max: 110)

                TableColumn("Avg Duration", value: \.avgDurationUs) { query in
                    Text(formatDuration(query.avgDurationUs))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 80, ideal: 100, max: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
            .contextMenu(forSelectionType: Int.self) { selection in
                if let queryId = selection.first,
                   let query = viewModel.topQueries.first(where: { $0.queryId == queryId }) {
                    Button {
                        onPopout?(query.queryText)
                    } label: {
                        Label("Expand SQL", systemImage: "arrow.up.left.and.arrow.down.right")
                    }

                    Button {
                        onOpenInQueryWindow?(query.queryText, viewModel.databaseName)
                    } label: {
                        Label("Open in Query Window", systemImage: "terminal")
                    }

                    Divider()

                    Button {
                        PlatformClipboard.copy(query.queryText)
                    } label: {
                        Label("Copy SQL", systemImage: "doc.on.doc")
                    }
                }
            } primaryAction: { _ in
                onDoubleClick?()
            }
            .onChange(of: viewModel.selectedQueryId) { _, newValue in
                if let queryId = newValue {
                    Task { await viewModel.selectQuery(queryId) }
                }
            }
            .overlay {
                if viewModel.topQueries.isEmpty {
                    ContentUnavailableView {
                        Label("No queries captured", systemImage: "chart.bar.xaxis")
                    } description: {
                        Text("Query Store is collecting data. Queries will appear here once executed.")
                    }
                }
            }
    }

    private var sortedQueries: [SQLServerQueryStoreTopQuery] {
        viewModel.topQueries.sorted(using: sortOrder)
    }
}

// MARK: - Formatting

extension QueryStoreTopQueriesSection {
    func formatDuration(_ microseconds: Double) -> String {
        if microseconds >= 1_000_000 {
            return String(format: "%.2fs", microseconds / 1_000_000)
        } else if microseconds >= 1_000 {
            return String(format: "%.1fms", microseconds / 1_000)
        } else {
            return String(format: "%.0f\u{00B5}s", microseconds)
        }
    }

    func formatCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return "\(value)"
        }
    }
}

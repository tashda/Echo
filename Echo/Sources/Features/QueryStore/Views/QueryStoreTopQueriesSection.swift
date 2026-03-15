import SwiftUI
import SQLServerKit

struct QueryStoreTopQueriesSection: View {
    @Bindable var viewModel: QueryStoreViewModel
    @State private var sortOrder = [
        KeyPathComparator(\SQLServerQueryStoreTopQuery.totalDurationUs, order: .reverse)
    ]

    var body: some View {
        SectionContainer(
            title: "Top Resource Consumers",
            icon: "flame.fill",
            info: "Queries consuming the most resources in Query Store, aggregated across all execution plans."
        ) {
            if viewModel.topQueries.isEmpty {
                emptyState
            } else {
                queryTable
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Text("No queries found in Query Store")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var queryTable: some View {
        Table(sortedQueries, selection: $viewModel.selectedQueryId, sortOrder: $sortOrder) {
            TableColumn("Query ID", value: \.queryId) { query in
                Text("\(query.queryId)")
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.primary)
            }
            .width(min: 60, ideal: 70, max: 80)

            TableColumn("Query Text", value: \.queryText) { query in
                Text(query.queryText.prefix(200))
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(2)
                    .help(String(query.queryText.prefix(500)))
            }
            .width(min: 200, ideal: 400)

            TableColumn("Executions", value: \.totalExecutions) { query in
                Text(formatCount(query.totalExecutions))
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 110)

            TableColumn("Total Duration", value: \.totalDurationUs) { query in
                Text(formatDuration(query.totalDurationUs))
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 110, max: 130)

            TableColumn("Total CPU", value: \.totalCPUUs) { query in
                Text(formatDuration(query.totalCPUUs))
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100, max: 120)

            TableColumn("Total I/O", value: \.totalIOReads) { query in
                Text(formatCount(Int(query.totalIOReads)))
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 110)

            TableColumn("Avg Duration", value: \.avgDurationUs) { query in
                Text(formatDuration(query.avgDurationUs))
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100, max: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .frame(minHeight: 300)
        .onChange(of: viewModel.selectedQueryId) { _, newValue in
            if let queryId = newValue {
                Task { await viewModel.selectQuery(queryId) }
            }
        }
    }

    private var sortedQueries: [SQLServerQueryStoreTopQuery] {
        viewModel.topQueries.sorted(using: sortOrder)
    }

    private func formatDuration(_ microseconds: Double) -> String {
        if microseconds >= 1_000_000 {
            return String(format: "%.2fs", microseconds / 1_000_000)
        } else if microseconds >= 1_000 {
            return String(format: "%.1fms", microseconds / 1_000)
        } else {
            return String(format: "%.0fus", microseconds)
        }
    }

    private func formatCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return "\(value)"
        }
    }
}

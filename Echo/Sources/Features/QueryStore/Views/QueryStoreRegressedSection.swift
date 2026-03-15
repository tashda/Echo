import SwiftUI
import SQLServerKit

struct QueryStoreRegressedSection: View {
    @Bindable var viewModel: QueryStoreViewModel
    @State private var sortOrder = [
        KeyPathComparator(\SQLServerQueryStoreRegressedQuery.regressionRatio, order: .reverse)
    ]

    var body: some View {
        SectionContainer(
            title: "Regressed Queries",
            icon: "chart.line.downtrend.xyaxis",
            info: "Queries with multiple execution plans where the worst plan is significantly slower than the best. A high regression ratio indicates plan instability."
        ) {
            if viewModel.regressedQueries.isEmpty {
                emptyState
            } else {
                regressedTable
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "checkmark.circle")
                .font(.title3)
                .foregroundStyle(ColorTokens.Status.success)
            Text("No regressed queries detected")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var regressedTable: some View {
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

            TableColumn("Plans", value: \.planCount) { query in
                Text("\(query.planCount)")
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 50, ideal: 60, max: 70)

            TableColumn("Best Avg", value: \.minAvgDurationUs) { query in
                Text(formatDuration(query.minAvgDurationUs))
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Status.success)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100, max: 120)

            TableColumn("Worst Avg", value: \.maxAvgDurationUs) { query in
                Text(formatDuration(query.maxAvgDurationUs))
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Status.error)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100, max: 120)

            TableColumn("Regression", value: \.regressionRatio) { query in
                Text(String(format: "%.1fx", query.regressionRatio))
                    .font(TypographyTokens.monospaced.weight(.semibold))
                    .foregroundStyle(regressionColor(query.regressionRatio))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .frame(minHeight: 250)
        .onChange(of: viewModel.selectedQueryId) { _, newValue in
            if let queryId = newValue {
                Task { await viewModel.selectQuery(queryId) }
            }
        }
    }

    private var sortedQueries: [SQLServerQueryStoreRegressedQuery] {
        viewModel.regressedQueries.sorted(using: sortOrder)
    }

    private func regressionColor(_ ratio: Double) -> Color {
        if ratio >= 10 { return ColorTokens.Status.error }
        if ratio >= 5 { return ColorTokens.Status.warning }
        return ColorTokens.Text.secondary
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
}

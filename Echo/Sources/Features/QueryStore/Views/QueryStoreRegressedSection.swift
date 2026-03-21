import SwiftUI
import SQLServerKit

struct QueryStoreRegressedSection: View {
    @Bindable var viewModel: QueryStoreViewModel
    var onDoubleClick: (() -> Void)?
    @State private var sortOrder = [
        KeyPathComparator(\SQLServerQueryStoreRegressedQuery.regressionRatio, order: .reverse)
    ]

    var body: some View {
        if viewModel.regressedQueries.isEmpty {
            ContentUnavailableView {
                Label("No regressed queries", systemImage: "checkmark.circle")
            } description: {
                Text("All queries are performing consistently. Regressions appear when a query has multiple plans with significantly different performance.")
            }
        } else {
            Table(sortedQueries, selection: $viewModel.selectedQueryId, sortOrder: $sortOrder) {
                TableColumn("ID", value: \.queryId) { query in
                    Text("\(query.queryId)")
                        .font(TypographyTokens.Table.numeric)
                }
                .width(min: 40, ideal: 55, max: 70)

                TableColumn("Query Text", value: \.queryText) { query in
                    let flat = query.queryText.replacingOccurrences(of: "\n", with: " ")
                        .replacingOccurrences(of: "\r", with: " ")
                        .replacingOccurrences(of: "  ", with: " ")
                    Text(flat.prefix(300))
                        .font(TypographyTokens.Table.sql)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(String(query.queryText.prefix(1000)))
                }
                .width(min: 250, ideal: 500)

                TableColumn("Plans", value: \.planCount) { query in
                    Text("\(query.planCount)")
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 50, ideal: 60, max: 70)

                TableColumn("Best Avg", value: \.minAvgDurationUs) { query in
                    Text(formatDuration(query.minAvgDurationUs))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Status.success)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 80, ideal: 100, max: 120)

                TableColumn("Worst Avg", value: \.maxAvgDurationUs) { query in
                    Text(formatDuration(query.maxAvgDurationUs))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Status.error)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 80, ideal: 100, max: 120)

                TableColumn("Regression", value: \.regressionRatio) { query in
                    Text(String(format: "%.1fx", query.regressionRatio))
                        .font(TypographyTokens.Table.percentage)
                        .foregroundStyle(regressionColor(query.regressionRatio))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 90, max: 100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: Int.self) { _ in
            } primaryAction: { _ in
                onDoubleClick?()
            }
            .onChange(of: viewModel.selectedQueryId) { _, newValue in
                if let queryId = newValue {
                    Task { await viewModel.selectQuery(queryId) }
                }
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
            return String(format: "%.0f\u{00B5}s", microseconds)
        }
    }
}

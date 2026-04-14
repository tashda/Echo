import SwiftUI

/// Full dashboard view for the Postgres activity monitor with 4 interactive charts.
struct PostgresDashboardView: View {
    @Bindable var viewModel: ActivityMonitorViewModel

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sm),
        GridItem(.flexible(), spacing: SpacingTokens.sm)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: SpacingTokens.sm) {
                DashboardChartView(
                    title: "Connections",
                    unit: "",
                    color: .blue,
                    data: viewModel.connectionCountHistory
                )

                DashboardChartView(
                    title: "Cache Hit Ratio",
                    unit: "%",
                    color: .green,
                    data: viewModel.cacheHitHistory,
                    maxValue: 100,
                    showAsPercentage: true
                )

                DashboardChartView(
                    title: "Transactions / sec",
                    unit: "/s",
                    color: .orange,
                    data: viewModel.throughputHistory
                )

                DashboardChartView(
                    title: "Dead Tuples",
                    unit: "",
                    color: .red,
                    data: viewModel.deadTuplesHistory
                )
            }
            .padding(SpacingTokens.md)
        }
    }
}

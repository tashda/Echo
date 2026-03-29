import SwiftUI

struct MySQLDashboardView: View {
    @Bindable var viewModel: ActivityMonitorViewModel

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sm),
        GridItem(.flexible(), spacing: SpacingTokens.sm)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: SpacingTokens.sm) {
                DashboardChartView(
                    title: "Queries / sec",
                    unit: "/s",
                    color: .orange,
                    data: viewModel.throughputHistory
                )

                DashboardChartView(
                    title: "Incoming Traffic",
                    unit: "KB/s",
                    color: .blue,
                    data: viewModel.ioHistory
                )

                DashboardChartView(
                    title: "Outgoing Traffic",
                    unit: "KB/s",
                    color: .teal,
                    data: viewModel.outgoingTrafficHistory
                )

                DashboardChartView(
                    title: "Buffer Pool",
                    unit: "%",
                    color: .green,
                    data: viewModel.cacheHitHistory,
                    maxValue: 100,
                    showAsPercentage: true
                )
            }
            .padding(SpacingTokens.md)
        }
    }
}

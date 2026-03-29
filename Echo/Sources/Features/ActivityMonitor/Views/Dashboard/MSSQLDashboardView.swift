import SwiftUI

/// Full dashboard view for the MSSQL activity monitor with 4 interactive charts.
struct MSSQLDashboardView: View {
    @Bindable var viewModel: ActivityMonitorViewModel

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sm),
        GridItem(.flexible(), spacing: SpacingTokens.sm)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: SpacingTokens.sm) {
                DashboardChartView(
                    title: "CPU Usage",
                    unit: "%",
                    color: .blue,
                    data: viewModel.cpuHistory,
                    maxValue: 100,
                    showAsPercentage: true
                )

                DashboardChartView(
                    title: "Batch Requests / sec",
                    unit: "/s",
                    color: .orange,
                    data: viewModel.throughputHistory
                )

                DashboardChartView(
                    title: "Waiting Tasks",
                    unit: "",
                    color: .red,
                    data: viewModel.waitingTasksHistory
                )

                DashboardChartView(
                    title: "Disk I/O (MB/s)",
                    unit: "MB/s",
                    color: .purple,
                    data: viewModel.ioHistory
                )
            }
            .padding(SpacingTokens.md)
        }
    }
}

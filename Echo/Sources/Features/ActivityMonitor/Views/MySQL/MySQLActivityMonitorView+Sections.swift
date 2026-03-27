import SwiftUI

extension MySQLActivityMonitorView {
    @ViewBuilder
    var sectionContentView: some View {
        switch selectedSection {
        case .overview:
            if let overview = mysqlSnapshot?.overview {
                MySQLActivityOverviewSection(overview: overview)
            }

            SectionContainer(
                title: "Performance Dashboard",
                icon: "chart.line.uptrend.xyaxis",
                info: "Query throughput, network traffic, and InnoDB buffer pool usage over time."
            ) {
                MySQLDashboardView(viewModel: viewModel)
            }
        case .variables:
            SectionContainer(
                title: "Server Variables",
                icon: "slider.horizontal.3",
                info: "Current global server variables grouped by prefix."
            ) {
                variablesContent
                    .padding(SpacingTokens.md)
            }
        case .processes:
            SectionContainer(
                title: "Process List",
                icon: "person.3",
                info: "Current connections from SHOW FULL PROCESSLIST."
            ) {
                processListContent
                    .padding(SpacingTokens.md)
            }
        }
    }

    @ViewBuilder
    var variablesContent: some View {
        if let variables = mysqlSnapshot?.globalVariables, !variables.isEmpty {
            Table(variables) {
                TableColumn("Variable") { variable in
                    Text(variable.name)
                        .font(TypographyTokens.Table.sql)
                }
                .width(min: 220, ideal: 280)

                TableColumn("Value") { variable in
                    Text(variable.value)
                        .font(TypographyTokens.Table.sql)
                        .textSelection(.enabled)
                }
                .width(min: 220, ideal: 360)

                TableColumn("Category") { variable in
                    Text(variable.category)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 80, ideal: 100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        } else {
            ActivitySectionLoadingView(title: "Server Variables", subtitle: "Loading server variables…")
        }
    }
}

import SwiftUI

extension MySQLActivityMonitorView {
    @ViewBuilder
    var sectionContentView: some View {
        switch selectedSection {
        case .overview:
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
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
                }
                .padding(SpacingTokens.md)
            }

        case .processes:
            processListContent

        case .queries:
            MySQLActivityQueries(viewModel: viewModel) { content in
                pushInspectorContent(content)
            } onPopout: { sql in
                selectedSQLContext = SQLPopoutContext(sql: sql, title: "Query Details", dialect: .mysql)
            }

        case .waits:
            MySQLActivityWaits(viewModel: viewModel)

        case .io:
            MySQLActivityIO(viewModel: viewModel)

        case .innodb:
            MySQLActivityInnoDB(viewModel: viewModel)

        case .replication:
            MySQLActivityReplication(viewModel: viewModel)

        case .reports:
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    MySQLPerformanceReportsSection(viewModel: viewModel)
                }
                .padding(SpacingTokens.md)
            }

        case .variables:
            variablesContent
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
            ActivitySectionLoadingView(title: "Server Variables", subtitle: "Loading server variables\u{2026}")
        }
    }
}

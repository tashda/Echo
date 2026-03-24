import SwiftUI
import SQLServerKit

struct IndexUsageSection: View {
    let stats: [SQLServerTuningClient.SQLServerIndexUsageStat]

    @State private var sortOrder = [
        KeyPathComparator(\SQLServerTuningClient.SQLServerIndexUsageStat.userUpdates, order: .reverse)
    ]

    private var sortedStats: [SQLServerTuningClient.SQLServerIndexUsageStat] {
        stats.sorted(using: sortOrder)
    }

    var body: some View {
        if stats.isEmpty {
            ContentUnavailableView {
                Label("No Index Usage Data", systemImage: "chart.bar.xaxis")
            } description: {
                Text("No index usage statistics available. Execute some queries first.")
            }
        } else {
            Table(sortedStats, sortOrder: $sortOrder) {
                TableColumn("Index Name", value: \.indexName) { stat in
                    Text(stat.indexName)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 120, ideal: 200)

                TableColumn("Table") { stat in
                    Text("\(stat.schemaName).\(stat.tableName)")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 120, ideal: 180)

                TableColumn("Type") { stat in
                    Text(stat.indexType)
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                .width(min: 60, ideal: 90)

                TableColumn("Seeks", value: \.userSeeks) { stat in
                    Text("\(stat.userSeeks)")
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(stat.userSeeks == 0 ? ColorTokens.Status.warning : ColorTokens.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 50, ideal: 70)

                TableColumn("Scans", value: \.userScans) { stat in
                    Text("\(stat.userScans)")
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 50, ideal: 70)

                TableColumn("Lookups", value: \.userLookups) { stat in
                    Text("\(stat.userLookups)")
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 50, ideal: 70)

                TableColumn("Updates", value: \.userUpdates) { stat in
                    Text("\(stat.userUpdates)")
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(isUnderutilized(stat) ? ColorTokens.Status.error : ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 50, ideal: 70)

                TableColumn("Last Seek") { stat in
                    if let date = stat.lastUserSeek {
                        Text(date)
                            .font(TypographyTokens.Table.date)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } else {
                        Text("\u{2014}")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
                .width(min: 80, ideal: 130)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
        }
    }

    private func isUnderutilized(_ stat: SQLServerTuningClient.SQLServerIndexUsageStat) -> Bool {
        stat.userUpdates > 100 && stat.userSeeks == 0 && stat.userScans == 0 && stat.userLookups == 0
    }
}

import SwiftUI
import SQLServerKit

struct QueryStoreWaitStatsSection: View {
    let waitStats: [SQLServerQueryStoreClient.SQLServerQueryStoreWaitStat]

    var body: some View {
        Table(waitStats) {
                TableColumn("Wait Category") { stat in
                    Text(stat.waitCategory)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 120, ideal: 200)

                TableColumn("Total Wait (ms)") { stat in
                    Text(String(format: "%.1f", stat.totalWaitTimeMs))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 80, ideal: 110)

                TableColumn("Avg Wait (ms)") { stat in
                    Text(String(format: "%.2f", stat.avgWaitTimeMs))
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 80, ideal: 100)

                TableColumn("Proportion") { stat in
                    waitBar(stat: stat)
                }
                .width(min: 80, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
            .overlay {
                if waitStats.isEmpty {
                    ContentUnavailableView {
                        Label("No Wait Statistics", systemImage: "clock")
                    } description: {
                        Text("No wait stats recorded for the selected query plan.")
                    }
                }
            }
    }

    private var maxTotal: Double {
        waitStats.map(\.totalWaitTimeMs).max() ?? 1
    }

    private func waitBar(stat: SQLServerQueryStoreClient.SQLServerQueryStoreWaitStat) -> some View {
        GeometryReader { geo in
            let ratio = maxTotal > 0 ? stat.totalWaitTimeMs / maxTotal : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(barColor(stat.waitCategory))
                    .frame(width: geo.size.width * min(max(ratio, 0), 1))
            }
        }
        .frame(height: 8)
        .padding(.vertical, SpacingTokens.xxs)
    }

    private func barColor(_ category: String) -> Color {
        switch category {
        case "CPU": return .orange
        case "Network I/O", "Network IO": return .blue
        case "Buffer I/O", "Buffer IO": return .green
        case "Memory": return .purple
        case "Lock": return .red
        case "Latch": return .yellow
        default: return .accentColor
        }
    }
}

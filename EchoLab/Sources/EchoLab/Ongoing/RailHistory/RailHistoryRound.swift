import SwiftUI

/// Round 39.4 · Rail tools: History. Echo today: the rail's History shows HistorySidebarView, a
/// placeholder ("Recent database operations and query history") with a disabled "Coming Soon"
/// button. Echo does record each run for the results panel's history (QueryHistoryPanelView).
@MainActor
enum RailHistoryRound {
    enum Grouping: String, CaseIterable {
        case day = "HG0 · By day, newest first"
        case tab = "HG1 · By tab"
        case server = "HG2 · By server, then day"
    }

    enum RowLook: String, CaseIterable {
        case line = "HR0 · The first line of SQL, then database · result · time"
        case card = "HR1 · Three lines of SQL in a card"
    }

    enum Keep: String, CaseIterable {
        case month = "HK0 · 30 days"
        case thousand = "HK1 · The last 5,000 runs"
        case forever = "HK2 · Until you clear it"
    }

    static let spec = RoundSpec(
        controls: [],
        exhibits: [
            .init(id: "proposal", title: "Accepted · query history", summary: "HG0 / HR0 / HK1 / HA1 / HP0. By day, first SQL line with database, result and time; 5,000 runs by default, with Cache limits and per-connection opt-out. Click opens a new tab without running SQL.", isEchoToday: true, isWide: true, designWidth: 860, designHeight: 520) { _ in
                RailToolsAcceptedScene(section: "History")
            },
        ], questions: []
    )

}

struct LabRHList: View {
    let grouping: RailHistoryRound.Grouping
    let row: RailHistoryRound.RowLook
    @State private var hovered: String?

    private var groups: [(String, [LabRTHistoryEntry])] {
        switch grouping {
        case .day, .server: ["Today", "Yesterday"].map { d in (d, LabRTHistoryEntry.samples.filter { $0.day == d }) }
        case .tab: [("Query 1", Array(LabRTHistoryEntry.samples.prefix(3))), ("Bag history", Array(LabRTHistoryEntry.samples.dropFirst(3)))]
        }
    }

    var body: some View {
        LabRTColumn(title: "History", subtitle: "dkloosql10-p and postgres18") {
            LabRTSearch(prompt: "Search history")
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.none) {
                    ForEach(groups, id: \.0) { title, entries in
                        LabRTHeading(title: grouping == .server ? "dkloosql10-p · \(title)" : title, count: entries.count)
                        ForEach(entries) { entry in
                            ZStack(alignment: .trailing) {
                                if row == .line {
                                    LabRTRow(symbol: entry.failed ? "xmark.circle.fill" : "checkmark.circle.fill", tint: entry.failed ? ColorTokens.Status.error : ColorTokens.Status.success,
                                             title: entry.sql, detail: "\(entry.database) · \(entry.rows) · \(entry.duration)", trailing: hovered == entry.id ? nil : entry.time, monoTitle: true)
                                } else {
                                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                        Text(entry.sql).font(TypographyTokens.detail.monospaced()).lineLimit(3)
                                        Text("\(entry.database) · \(entry.rows) · \(entry.time)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                                    }
                                    .padding(SpacingTokens.xs).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: SpacingTokens.xs))
                                    .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                                }
                                if hovered == entry.id {
                                    HStack(spacing: SpacingTokens.xs) { Image(systemName: "play.fill"); Image(systemName: "ellipsis") }
                                        .font(TypographyTokens.detail).padding(.horizontal, SpacingTokens.xs).frame(height: SpacingTokens.lg - SpacingTokens.xxs)
                                        .glassEffect(.regular, in: .capsule).padding(.trailing, SpacingTokens.sm)
                                }
                            }
                            .onHover { hovered = $0 ? entry.id : (hovered == entry.id ? nil : hovered) }
                        }
                    }
                }
            }
        }
    }
}

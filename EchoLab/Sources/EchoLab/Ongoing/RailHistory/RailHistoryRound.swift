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
        controls: [
            .of("grouping", "Grouping", Grouping.self, default: .day,
                question: "How should the history be grouped?",
                recommend: .day,
                why: "You remember when you ran something ('yesterday afternoon') more than which tab it was in, and tabs come and go. The server is on each row; filter by it with the search's server token."),
            .of("row", "Rows", RowLook.self, default: .line,
                question: "Compare the row styles.",
                recommend: .line,
                why: "One line of SQL is enough to recognise a query you wrote; hovering shows the whole of it. Cards fit a third as many runs."),
            .of("keep", "Kept for", Keep.self, default: .thousand,
                question: "How long should history be kept?",
                recommend: .thousand,
                why: "A count keeps the file small however much you run; 5,000 is months of work for most people. A setting can change it."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Coming Soon.", isEchoToday: true, isWide: true, designWidth: 760, designHeight: 440) { _ in
                LabRTScene(selected: 2) {
                    VStack(spacing: SpacingTokens.lg) {
                        Image(systemName: "clock.fill").font(TypographyTokens.title).foregroundStyle(ColorTokens.Text.tertiary)
                        Text("History").font(TypographyTokens.title2.weight(.semibold))
                        Text("Recent database operations and query history").font(TypographyTokens.subheadline).foregroundStyle(ColorTokens.Text.secondary).multilineTextAlignment(.center)
                        Button("Coming Soon") {}.buttonStyle(.bordered).disabled(true)
                    }
                    .padding(SpacingTokens.lg).frame(width: 260).frame(maxHeight: .infinity).workspaceCard()
                }
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Hover a row for its actions.", isWide: true, designWidth: 760, designHeight: 440) { values in
                LabRTScene(selected: 2) {
                    LabRHList(grouping: Grouping(rawValue: values["grouping"]) ?? .day, row: RowLook(rawValue: values["row"]) ?? .line)
                }
            },
        ],
        questions: [
            .init(id: "actions", title: "A past query",
                  question: "What can you do with a row?",
                  choices: [.init(id: "all", name: "HA0 · Open in a new tab (click), Run Again, Copy, Add to Bookmarks (menu)"),
                            .init(id: "open", name: "HA1 · Open in a new tab only")],
                  recommended: "all",
                  why: "Run Again on a recent SELECT is the most common reason to look back; Add to Bookmarks turns 'I keep running this' into a bookmark."),
            .init(id: "sensitive", title: "Servers you don't want recorded",
                  question: "Should a connection be able to switch history off?",
                  choices: [.init(id: "yes", name: "HP0 · Yes: Don't keep history, in the connection's settings"), .init(id: "no", name: "HP1 · No")],
                  recommended: "yes",
                  why: "Queries against production can hold personal data in their WHERE clauses; the people who need this need it per connection."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["grouping": Grouping.day.rawValue, "row": RowLook.line.rawValue, "keep": Keep.thousand.rawValue], isRecommended: true)]
    )
}

private struct LabRHList: View {
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

import SwiftUI

/// Round 35.3 · Tab overview: grouping, order and search. Echo today (TabOverviewView+Grouping,
/// TabOverviewHeader): tabs grouped three levels deep, server (active first, then by name) ›
/// database (`activeDatabaseName`) › kind (QUERIES, JOBS…); a header with "Open Tabs", "9 tabs · 2
/// running", Collapse All and Expand All; no search.
@MainActor
enum TabOverviewGroupingRound {
    enum GroupBy: String, CaseIterable {
        case today = "GB0 · Server › database › kind (today)"
        case server = "GB1 · Server only"
        case serverDatabase = "GB2 · Server › database"
        case none = "GB3 · No groups: one grid"
        case kind = "GB4 · By kind: queries, then tools"
    }

    enum Order: String, CaseIterable {
        case strip = "OO0 · The tab strip's order (today)"
        case recent = "OO1 · Last used first"
        case name = "OO2 · By name"
    }

    enum Header: String, CaseIterable {
        case today = "HE0 · Title, count, Collapse All and Expand All (today)"
        case search = "HE1 · A search field and the count"
        case searchFilters = "HE2 · A search field with Running, Failed, Queries and Tools filters"
    }

    static let spec = RoundSpec(
        controls: [
            .of("groupBy", "Groups", GroupBy.self, default: .server,
                question: "Compare the groupings with the nine tabs. How many levels should there be?",
                recommend: .server,
                why: "Most of the noise today is the three nested headings for nine tabs. The server is the one level that matters (it is where a query runs); the database is on each card already, and kind is visible in the snapshot. With one server the heading disappears altogether."),
            .of("order", "Order", Order.self, default: .strip,
                question: "How should cards be ordered inside a group?",
                recommend: .strip,
                why: "The overview is a map of the tab strip: the same order lets your eye carry over in both directions. Last used first reorders cards every time you look, which breaks spatial memory."),
            .of("header", "Header", Header.self, default: .searchFilters,
                question: "Look at the top of the overview.",
                recommend: .searchFilters,
                why: "Collapse All and Expand All go away with the nesting; a search field (focused as soon as you type) plus two state filters answers 'which tab is running?' and 'what failed?' in one click.")
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Three levels of grouping and Collapse All / Expand All.",
                  isEchoToday: true, isWide: true, designWidth: 760, designHeight: 470) { _ in
                LabTOToday()
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Type in the search field.",
                  isWide: true, designWidth: 760, designHeight: 470) { values in
                LabTOGrouped(groupBy: GroupBy(rawValue: values["groupBy"]) ?? .server, order: Order(rawValue: values["order"]) ?? .strip,
                             header: Header(rawValue: values["header"]) ?? .searchFilters)
            },
        ],
        questions: [
            .init(id: "typing", title: "Typing",
                  question: "With the overview open, you start typing without clicking the field. What happens?",
                  choices: [
                      .init(id: "search", name: "TY0 · It searches: titles, databases and the SQL in the tabs"),
                      .init(id: "nothing", name: "TY1 · Nothing until you click the field"),
                  ],
                  recommended: "search",
                  why: "Safari's overview and Mission Control in Spotlight work this way; it makes the overview a quick switcher for free."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", values: ["groupBy": GroupBy.server.rawValue, "order": Order.strip.rawValue,
                                                                         "header": Header.searchFilters.rawValue], isRecommended: true),
        ]
    )
}

/// The overview's grid with the chosen grouping, order and header.
private struct LabTOGrouped: View {
    let groupBy: TabOverviewGroupingRound.GroupBy
    let order: TabOverviewGroupingRound.Order
    let header: TabOverviewGroupingRound.Header
    @State private var query = ""
    @State private var filter: String?

    private var tabs: [LabTOTab] {
        var result = LabTOTab.samples.filter { query.isEmpty || ($0.title + ($0.database ?? "") + $0.sql.joined()).localizedCaseInsensitiveContains(query) }
        switch filter {
        case "Running": result = result.filter { if case .running = $0.status { true } else { false } }
        case "Failed": result = result.filter { $0.status == .failed }
        case "Queries": result = result.filter { $0.kind == .query }
        case "Tools": result = result.filter { $0.kind != .query }
        default: break
        }
        switch order {
        case .strip: return result
        case .recent: return result.sorted { rank($0.ago) < rank($1.ago) }
        case .name: return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private func rank(_ ago: String) -> Int {
        if ago == "now" { return 0 }
        if ago.hasSuffix("s ago") { return 1 }
        if ago.hasSuffix("min ago") { return 10 + (Int(ago.split(separator: " ").first ?? "") ?? 0) }
        return 1000
    }

    private var groups: [(String, [LabTOTab])] {
        switch groupBy {
        case .none: return [("", tabs)]
        case .kind: return [("Queries", tabs.filter { $0.kind == .query }), ("Tools", tabs.filter { $0.kind != .query })].filter { !$0.1.isEmpty }
        case .server, .today: return LabTOTab.servers.map { s in (s, tabs.filter { $0.server == s }) }.filter { !$0.1.isEmpty }
        case .serverDatabase:
            return LabTOTab.servers.flatMap { s in
                Array(Set(tabs.filter { $0.server == s }.map { $0.database ?? "Server" })).sorted().map { d in
                    ("\(s) › \(d)", tabs.filter { $0.server == s && ($0.database ?? "Server") == d })
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            headerView
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    ForEach(groups, id: \.0) { title, items in
                        if !title.isEmpty {
                            Text(title).font(TypographyTokens.headline)
                                + Text("  \(items.count)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm), count: 4), spacing: SpacingTokens.sm) {
                            ForEach(items) { LabTOCard(tab: $0, isActive: $0.id == LabTOTab.activeID, statusLook: .ring) }
                        }
                    }
                }
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }

    @ViewBuilder
    private var headerView: some View {
        switch header {
        case .today:
            HStack {
                Text("Open Tabs").font(TypographyTokens.headline)
                Text("\(tabs.count) tabs · 2 running").foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                Button("Collapse All") {}.controlSize(.small)
                Button("Expand All") {}.controlSize(.small)
            }
        case .search, .searchFilters:
            HStack(spacing: SpacingTokens.xs) {
                TextField("Search", text: $query, prompt: Text("Search tabs"))
                    .textFieldStyle(.roundedBorder).frame(width: 240)
                if header == .searchFilters {
                    ForEach(["Running", "Failed", "Queries", "Tools"], id: \.self) { name in
                        Button(name) { filter = filter == name ? nil : name }
                            .buttonStyle(.bordered).controlSize(.small)
                            .tint(filter == name ? ColorTokens.accent : nil)
                    }
                }
                Spacer()
                Text("\(tabs.count) of \(LabTOTab.samples.count) tabs").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }
}

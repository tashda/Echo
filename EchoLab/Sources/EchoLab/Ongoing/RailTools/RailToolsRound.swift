import SwiftUI

/// Round 39.1 · Rail tools: keep, merge or move. Echo today (SidebarMenu.NavSection,
/// SidebarMenuView+Content): four buttons in the rail's bottom pill (Bookmarks, Snippets, History,
/// Clipboard) each replace the tree column. History is a "Coming Soon" placeholder with a disabled
/// button (HistorySidebarView), though Echo records query history for the results panel
/// (QueryHistoryPanelView). Snippets lists the built-in catalog for the dialect. Clipboard is Echo's
/// own history of copies. Bookmarks keeps SQL per server, saved from a tab's or a selection's menu.
@MainActor
enum RailToolsRound {
    enum Placement: String, CaseIterable {
        case today = "RT0 · Four rail buttons, each replacing the tree (today)"
        case library = "RT1 · One Library button: Bookmarks, Snippets and History as sections"
        case inspector = "RT2 · Panels in the inspector column, beside the tab"
        case palette = "RT3 · No panel: one search palette over the window (⇧⌘L)"
        case editor = "RT4 · In the editor: an Insert button that opens a popover"

        var summary: String {
            switch self {
            case .today: "Each tool takes the tree's place; you lose the tree while you look at a bookmark."
            case .library: "One button and one column with a section control at the top; the three are all 'SQL you can reuse'."
            case .inspector: "The tree stays; the library sits on the right, where the inspector is, so you can drag SQL into the editor between them."
            case .palette: "Fast for finding something you know; nothing to browse."
            case .editor: "Next to where the SQL goes; only useful in a query tab."
            }
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("placement", "Where they live", Placement.self, default: .inspector,
                question: "Look at each placement. Where should saved SQL, snippets and history live?",
                recommend: .inspector,
                why: "They are all SQL you reuse in the editor, so they belong beside it, not instead of the tree you need to see what the SQL touches. The inspector column is already the place for 'details of what I'm working on'; a library tab there keeps both the tree and the editor on screen and lets you drag SQL across. RT1 is the closest alternative if you'd rather keep the right side for the inspector.",
                summary: \.summary),
        ],
        exhibits: Placement.allCases.map { placement in
            RoundSpec.Exhibit(id: "\(placement)", title: placement.rawValue, summary: placement.summary, isEchoToday: placement == .today,
                              isWide: true, designWidth: 860, designHeight: 440) { _ in
                LabRTPlacementView(placement: placement)
            }
        },
        questions: [
            .init(id: "bookmarks", title: "Bookmarks", question: "Keep Bookmarks?",
                  choices: [.init(id: "keep", name: "KB0 · Keep, redesigned (39.2)"), .init(id: "drop", name: "KB1 · Drop")],
                  recommended: "keep",
                  why: "Saved queries are the one thing here people ask for in every database tool (SSMS's Template Explorer, DataGrip's scratches); Echo already syncs them."),
            .init(id: "snippets", title: "Snippets", question: "Keep Snippets?",
                  choices: [.init(id: "keep", name: "KS0 · Keep, with your own snippets (39.3)"),
                            .init(id: "echosense", name: "KS1 · Only through EchoSense: type a prefix, no list"),
                            .init(id: "drop", name: "KS2 · Drop")],
                  recommended: "keep",
                  why: "Snippets you write yourself are the reason to have a list; built-ins alone are better as EchoSense completions, which 39.3 adds either way."),
            .init(id: "history", title: "History", question: "Build History?",
                  choices: [.init(id: "build", name: "KH0 · Build it (39.4), and remove Coming Soon"), .init(id: "drop", name: "KH1 · Drop the rail button; history stays in the results panel")],
                  recommended: "build",
                  why: "'What did I run on production yesterday?' is the question; Echo records it already, so this is mostly showing what exists."),
            .init(id: "clipboard", title: "Clipboard", question: "Keep Echo's clipboard history?",
                  choices: [.init(id: "drop", name: "KC0 · Drop it: macOS 26 keeps clipboard history in Spotlight (39.5)"),
                            .init(id: "keep", name: "KC1 · Keep it")],
                  recommended: "drop",
                  why: "The system now does this for every app, with search and privacy controls; a second history inside Echo is something to learn, sync and secure for no gain."),
        ],
        exhibitTopic: ("Which placement?", "Which placement should the library get?", "\(Placement.inspector)",
                       "Beside the editor in the inspector column: the tree stays, and SQL can be dragged from the library into the editor."),
        presets: [.init(id: "recommended", name: "My recommendation", values: ["placement": Placement.inspector.rawValue], isRecommended: true)]
    )
}

/// The window's left and centre in one placement.
private struct LabRTPlacementView: View {
    let placement: RailToolsRound.Placement
    @State private var section = "Bookmarks"

    var body: some View {
        switch placement {
        case .today:
            LabRTScene(selected: 0) { LabRTBookmarksToday() }
        case .library:
            LabRTScene(symbols: ["books.vertical"], selected: 0) {
                LabRTColumn(title: "Library", trailing: nil) {
                    Picker("Section", selection: $section) { ForEach(["Bookmarks", "Snippets", "History"], id: \.self) { Text($0).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden().padding(.horizontal, SpacingTokens.xs).padding(.bottom, SpacingTokens.xs)
                    LabRTSearch(prompt: "Search \(section.lowercased())")
                    LabRTLibraryList(section: section)
                }
            }
        case .inspector:
            HStack(spacing: SpacingTokens.xs) {
                LabRTRail(symbols: [], selected: nil)
                LabSHCard(server: .production, look: .today, rowLimit: 6).frame(width: 220).frame(maxHeight: .infinity, alignment: .top)
                LabWKEditor().workspaceCard()
                VStack(alignment: .leading, spacing: SpacingTokens.none) {
                    Picker("Section", selection: $section) { ForEach(["Bookmarks", "Snippets", "History"], id: \.self) { Text($0).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden().padding(SpacingTokens.xs)
                    LabRTSearch(prompt: "Search")
                    LabRTLibraryList(section: section)
                    Spacer(minLength: 0)
                }
                .frame(width: 250).workspaceCard()
            }
            .padding(SpacingTokens.sm).background(ColorTokens.Workspace.canvas)
        case .palette:
            ZStack {
                LabRTScene(symbols: [], selected: nil) { LabSHCard(server: .production, look: .today, rowLimit: 6).frame(width: 220) }.opacity(0.45)
                VStack(alignment: .leading, spacing: SpacingTokens.none) {
                    HStack { Image(systemName: "magnifyingglass"); Text("checkpoint").foregroundStyle(ColorTokens.Text.primary); Spacer(); Text("⇧⌘L").foregroundStyle(ColorTokens.Text.tertiary) }
                        .font(TypographyTokens.prominent).padding(SpacingTokens.sm)
                    Divider()
                    LabRTHeading(title: "Bookmarks")
                    LabRTRow(symbol: "bookmark", title: "Last checkpoints", detail: "ESB_INTEGRATION")
                    LabRTRow(symbol: "bookmark", title: "Reset OH checkpoint", detail: "ESB_INTEGRATION")
                    LabRTHeading(title: "History")
                    LabRTRow(symbol: "clock", title: "select * from dbo.aml_checkpoint", detail: "Today 15:34 · 3 rows", monoTitle: true)
                }
                .frame(width: 420).padding(.bottom, SpacingTokens.xs)
                .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.md2))
            }
        case .editor:
            HStack(spacing: SpacingTokens.xs) {
                LabRTRail(symbols: [], selected: nil)
                LabSHCard(server: .production, look: .today, rowLimit: 6).frame(width: 220).frame(maxHeight: .infinity, alignment: .top)
                ZStack(alignment: .topLeading) {
                    LabWKEditor().workspaceCard()
                    VStack(alignment: .leading, spacing: SpacingTokens.none) {
                        LabRTSearch(prompt: "Insert a bookmark, snippet or past query").padding(.top, SpacingTokens.xs)
                        LabRTLibraryList(section: "Bookmarks")
                    }
                    .frame(width: 320, height: 240)
                    .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.md))
                    .padding(.leading, SpacingTokens.xxxl).padding(.top, SpacingTokens.xxxl + SpacingTokens.lg)
                }
            }
            .padding(SpacingTokens.sm).background(ColorTokens.Workspace.canvas)
        }
    }
}

/// The library's rows for a section, in the proposal's quiet style.
struct LabRTLibraryList: View {
    let section: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                switch section {
                case "Snippets":
                    ForEach(LabRTSnippet.samples) { LabRTRow(symbol: $0.isYours ? "person.crop.circle" : "curlybraces", title: $0.name, detail: $0.body, trailing: $0.prefix) }
                case "History":
                    ForEach(LabRTHistoryEntry.samples.prefix(5)) { entry in
                        LabRTRow(symbol: entry.failed ? "xmark.circle.fill" : "checkmark.circle.fill", tint: entry.failed ? ColorTokens.Status.error : ColorTokens.Status.success,
                                 title: entry.sql, detail: "\(entry.database) · \(entry.rows)", trailing: entry.time, monoTitle: true)
                    }
                default:
                    ForEach(LabRTBookmark.samples.prefix(4)) { LabRTRow(symbol: "bookmark", title: $0.title, detail: $0.sql, trailing: $0.database.prefix(8).description) }
                }
            }
        }
    }
}

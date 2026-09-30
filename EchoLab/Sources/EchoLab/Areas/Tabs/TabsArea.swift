import SwiftUI

/// The tab strip and tool pages as they are in Echo today: Round 9's strip on one line, and a
/// tool's pages unfolding inside its active tab (decisions 2026-09-30, plan Phase 14 and 15).
@MainActor
enum TabsArea {
    static let area = LabArea(
        id: "tabs",
        title: "Tabs and tool pages",
        symbol: "rectangle.topthird.inset.filled",
        summary: "Safari-style tabs on one line over the cards. A tool with pages, such as Activity Monitor, shows them as chips inside its own tab.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "a24192df", date: "2026-09-30",
                note: "The specimen is Round 14's window with the R9 strip and the tab-unfolds pages. Written from the decision log; measurements not yet read from the tab strip's code."),
            stageHeight: 560,
            behaviours: [
                .init(trigger: "Click a tab", result: "Selects at once. Tabs are real buttons; dragging still reorders them."),
                .init(trigger: "Switch back to a recent tab", result: "Its editor is still alive: scroll, undo history and cursor are where you left them."),
                .init(trigger: "Hover a tab", result: "The close button appears; the tooltip shows the database."),
                .init(trigger: "Query running", result: "A spinner replaces the tab's icon at the leading edge; the timer lives in the tooltip and the tab overview."),
                .init(trigger: "Many tabs", result: "Tabs shrink to a minimum width, then inactive tabs collapse to their icon while the active tab keeps its title."),
                .init(trigger: "Click +", result: "The new tab grows out of the + button."),
                .init(trigger: "Open a tool with pages", result: "The tool's tab unfolds and shows its pages as small chips inside itself; the other tabs make room."),
                .init(trigger: "Leave the tool tab", result: "The pages fold back into the tab."),
                .init(trigger: "Pinch, ⇧⌘O, or the toolbar button", result: "Opens the tab overview: tabs grouped by server, active server first."),
            ],
            motions: [
                .init(name: "Tabs make room for pages", curve: "house spring, bounce 0.08", duration: "0.45s", note: "echoMotion.standard"),
                .init(name: "New tab", curve: "grows out of +", duration: "0.45s"),
                .init(name: "Tab overview", curve: "active tab zooms out into its card and back", duration: "not measured"),
            ],
            measurements: [
                .init(label: "Strip", value: "Grey plate, raised white active tab", token: "Round 9 strip (R9 · Today)"),
                .init(label: "Lines per tab", value: "One", token: "decided 2026-09-30"),
                .init(label: "Icon", value: "The tab's kind; a spinner while running"),
                .init(label: "Position", value: "On the canvas above both cards"),
                .init(label: "Page chip height", value: "20pt", token: "LayoutTokens.TabPages.chipHeight"),
                .init(label: "Page chip padding", value: "8pt horizontal", token: "LayoutTokens.TabPages.chipHorizontalPadding"),
                .init(label: "Chrome around a pages tab", value: "76pt", token: "LayoutTokens.TabPages.tabChrome"),
                .init(label: "Largest share of the strip", value: "62%", token: "LayoutTokens.TabPages.maxShareOfStrip"),
            ],
            rules: [
                .init(text: "Tabs look and behave like Safari's",
                      why: "It is the reference every Mac user already knows.",
                      rounds: ["ported.Round 14 · tab bar and pages"]),
                .init(text: "Round 9's strip, on one line",
                      why: "The glass capsule with two lines (rounds 11 and 12) was regretted; the grey plate reads stronger. Options N1, N1R and N4 to N9 were rejected.",
                      rounds: ["decided.round9-footer-scroller-tabs", "decided.round13-tab-directions", "ported.Round 14 · tab bar and pages"]),
                .init(text: "The database is in the tooltip",
                      why: "One line keeps the strip calm; the database is secondary and one hover away.",
                      rounds: ["decided.round12-two-line-tabs"]),
                .init(text: "A tool's pages unfold inside its tab (ST2)",
                      why: "Replaces the segmented control at the top of tool tabs. Drawer, tab group, page menu and second bar were rejected.",
                      rounds: ["ported.Round 14 · tab bar and pages"]),
                .init(text: "Switching is instant",
                      why: "Real buttons and live editors for recent tabs fixed the sluggish switching.",
                      rounds: ["decided.round9-footer-scroller-tabs"]),
            ],
            code: [
                "Echo/Sources/Features/AppHost/Views/Tabs/TabStrip/",
                "Echo/Sources/Features/AppHost/Views/Tabs/TabStrip/TabPageChips.swift",
                "Echo/Sources/Features/AppHost/Views/Tabs/TabStrip/QueryTabStrip+Unfold.swift",
                "Packages/EchoDesignSystem/.../LayoutToken+TabPages.swift",
            ]
        ) {
            TabsSpecimen()
        }
    )
}

private struct TabsSpecimen: View {
    @Environment(\.echoMotion) private var motion

    var body: some View {
        LabRound14TabWindow(style: .today, pageStyle: .unfold, animation: motion.standard)
            .scaleEffect(0.86)
    }
}

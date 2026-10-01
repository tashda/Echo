import SwiftUI

/// Tool tabs as they are in Echo today: one header, the toolbar row on the canvas, dashboard
/// tiles for monitoring tools, and every pane its own card (Design plan, Phase 15).
@MainActor
enum ToolTabsArea {
    private static let header = "Echo/Sources/Shared/DesignSystem/Components/ToolTabHeader.swift"
    private static let container = "Echo/Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/ToolTabContainer.swift"
    private static let split = "Echo/Sources/Shared/DesignSystem/Components/CardSplitView.swift"
    private static let tiles = "Echo/Sources/Features/ActivityMonitor/Views/ActivityMonitorSparklineStrip.swift"

    static let area = LabArea(
        id: "tool-tabs",
        title: "Tool tabs",
        symbol: "square.grid.2x2",
        summary: "Every tool tab starts with one header on the canvas; its panes are cards a gutter apart; monitoring tools open on dashboard tiles.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "d4659ef6", date: "2026-09-30",
                note: "Read from ToolTabHeader, ToolTabContainer, CardSplitView, ActivityMonitorSparklineStrip and Design/05-components. The specimen is a stand-in Activity Monitor; not compared with the running app."),
            stageHeight: 380,
            behaviours: [
                .init(trigger: "Open a tool", result: "A tab opens with the tool's header on the canvas, then its panes on cards."),
                .init(trigger: "A tool with pages", result: "The pages unfold as chips inside the tool's tab (see Tabs)."),
                .init(trigger: "A page that brings its own cards", result: "The one big card steps aside (adaptiveWorkspaceCard)."),
                .init(trigger: "Drag the gap between panes", result: "Resizes them; double-click maximises where the tool supports it."),
                .init(trigger: "Open a tool's bottom panel", result: "It grows up out of the status bar like the query tab's results, and folds back; ⌥⇧⌘Y maximises it to a one-line content card."),
                .init(trigger: "Monitoring tool", result: "Opens on dashboard tiles: the key figures with sparklines above the detail."),
            ],
            motions: [
                .init(name: "Bottom panel grows and folds", curve: "house spring out, smooth in", duration: "0.45s", note: "the same as the query tab's results"),
            ],
            measurements: [
                .init(label: "Header height", value: "40pt", token: "LayoutTokens.ToolTab.headerHeight"),
                .init(label: "Header icon", value: "14pt symbol in a 28pt tinted box, corner 7pt", token: "iconSize / iconBoxSize / iconCornerRadius"),
                .init(label: "Title", value: "13pt semibold", token: "TypographyTokens.standard"),
                .init(label: "Subtitle", value: "11pt secondary, tabular digits: server · database · freshness", token: "TypographyTokens.detail"),
                .init(label: "Tile height", value: "76pt", token: "LayoutTokens.ToolTab.tileHeight"),
                .init(label: "Tile sparkline", value: "28pt high", token: "LayoutTokens.ToolTab.tileSparklineHeight"),
                .init(label: "Gap between cards", value: "4, 6 or 8pt (setting)", token: "workspaceGutter"),
            ],
            rules: [
                .init(text: "One header for every tool tab (TT2)", why: "The tool's icon, title, server and freshness, with its actions on the right: every tool reads the same."),
                .init(text: "Panes are cards (TT1)", why: "The same cards as the editor and results, a gutter apart, so a tool tab belongs to the window."),
                .init(text: "The toolbar row sits on the canvas under the header", why: "Once panes are cards, a toolbar inside a card would double the chrome."),
                .init(text: "A pane that compares two things of one object keeps them in one card", why: "A session's events and targets, or source and target DDL, are one subject."),
                .init(text: "Monitoring tools open on tiles (TT3)", why: "The key figures first, the detail below."),
                .init(text: "Configuration stays in the tab", why: "Read-only detail, such as a job's history, may use the Inspector."),
            ],
            code: [header, container, split, tiles, "Design/05-components.md › Tool tabs"]
        ) {
            ToolTabsSpecimen()
        },
        spec: ToolTabsSpec.spec(stageHeight: 380) { ToolTabsSpecimen() }
    )
}

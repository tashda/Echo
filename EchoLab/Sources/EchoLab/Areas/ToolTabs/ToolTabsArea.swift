import SwiftUI

/// Tool tabs as they are in Echo today: one header, the toolbar row on the canvas, dashboard
/// tiles for monitoring tools, and every pane its own card (Design plan, Phase 15).
@MainActor
enum ToolTabsArea {
    private static let header = "Echo/Sources/Shared/DesignSystem/Components/ToolTabHeader.swift"
    private static let container = "Echo/Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/ToolTabContainer.swift"
    private static let split = "Echo/Sources/Shared/DesignSystem/Components/CardSplitView.swift"
    private static let tiles = "Echo/Sources/Features/ActivityMonitor/Views/ActivityMonitorSparklineStrip.swift"
    private static let paneHeader = "Echo/Sources/Shared/DesignSystem/Components/PaneHeader.swift"
    private static let jobs = "Echo/Sources/Features/AppHost/Views/Navigation/JobManagement/JobQueue/JobQueueView.swift"
    private static let controls = "Echo/Sources/Shared/DesignSystem/Components/ToolTabControls"
    private static let family = "Echo/Sources/Features/AppHost/Domain/ToolTabFamily.swift"
    private static let tabToolbar = "Echo/Sources/Shared/DesignSystem/Components/TabToolbar"

    static let area = LabArea(
        id: "tool-tabs",
        title: "Tool tabs",
        symbol: "square.grid.2x2",
        summary: "Every tab but the editors belongs to a family and starts with one header line holding the tool's glass controls; its pages are in the tab, its panes cards a gutter apart, and each family has its layout.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "415e4115", date: "2026-10-01",
                note: "Read from ToolTabHeader, ToolTabContainer, CardSplitView, ActivityMonitorSparklineStrip and Design/05-components. The specimen is a stand-in Activity Monitor; not compared with the running app."),
            stageHeight: 380,
            behaviours: [
                .init(trigger: "Open a tool", result: "A tab opens with the tool's header on the canvas, its pickers and search on the same line, then its panes on cards; its buttons appear in the window toolbar (round 37.5)."),
                .init(trigger: "A tool with pages", result: "The pages are in the tool's tab (see Tabs); it reopens on the last page used on that server (round 36.2)."),
                .init(trigger: "Start something that runs", result: "The main action turns into Stop with a pulsing red dot (round 37.3, ST1)."),
                .init(trigger: "A Health page", result: "Its findings come first, worst first, each with a fix: Back Up Now, Rebuild, Vacuum (round 37.4)."),
                .init(trigger: "Change a Properties tool", result: "An Apply bar at the bottom counts the changes, with Revert and Apply (round 37.4)."),
                .init(trigger: "A Canvas tool", result: "Zoom, fit and what to show float in a glass bar at the bottom of the drawing (round 37.4)."),
                .init(trigger: "Any tab in front", result: "Its own buttons are native toolbar items before the window's icons: its special button with its word, then each group of its other buttons; they change in place as you switch tabs (round 37.5)."),
                .init(trigger: "A page that brings its own cards", result: "The one big card steps aside (adaptiveWorkspaceCard)."),
                .init(trigger: "Drag the gap between panes", result: "Resizes them; double-click maximises where the tool supports it."),
                .init(trigger: "Open a tool's bottom panel", result: "It grows up out of the status bar like the query tab's results, and folds back; ⌥⇧⌘Y maximises it to a one-line content card."),
                .init(trigger: "Monitoring tool", result: "Opens on dashboard tiles: the key figures with sparklines above the detail."),
                .init(trigger: "Agent Jobs", result: "Jobs the full height on the left, Details over History on the right; each pane with the one pane header (round 33)."),
                .init(trigger: "New Step or Edit Step", result: "A wide sheet: the command full height in the SQL editor with Parse, the step's settings and what it does when it finishes in a sidebar at the right; Edit Step shows how the step last ran (round 33.2)."),
                .init(trigger: "Agent Jobs in front", result: "Open in New Window is the toolbar's first item on the right, in its own glass; the header shows the tree's clock."),
                .init(trigger: "Double-click a step or a schedule", result: "Edit Step or Edit Schedule opens on it."),
                .init(trigger: "A job runs", result: "Its symbol spins and Last Run counts up from when the Agent started it; the list reloads when it ends."),
            ],
            motions: [
                .init(name: "Bottom panel grows and folds", curve: "house spring out, smooth in", duration: "0.45s", note: "the same as the query tab's results"),
            ],
            measurements: [
                .init(label: "Header height", value: "40pt", token: "LayoutTokens.ToolTab.headerHeight"),
                .init(label: "Header controls", value: "28pt glass, 8pt apart", token: "LayoutTokens.ToolTab.controlHeight"),
                .init(label: "Search field", value: "140pt", token: "LayoutTokens.ToolTab.searchFieldWidth"),
                .init(label: "Canvas bar", value: "30pt glass capsule, 12pt above the bottom", token: "LayoutTokens.ToolTab.canvasBarHeight"),
                .init(label: "Header icon", value: "14pt symbol in a 28pt tinted box, corner 7pt", token: "iconSize / iconBoxSize / iconCornerRadius"),
                .init(label: "Title", value: "13pt semibold", token: "TypographyTokens.standard"),
                .init(label: "Subtitle", value: "11pt secondary, tabular digits: server · database · freshness", token: "TypographyTokens.detail"),
                .init(label: "Tile height", value: "76pt", token: "LayoutTokens.ToolTab.tileHeight"),
                .init(label: "Tile sparkline", value: "28pt high", token: "LayoutTokens.ToolTab.tileSparklineHeight"),
                .init(label: "Gap between cards", value: "4, 6 or 8pt (setting)", token: "workspaceGutter"),
                .init(label: "Pane header", value: "36pt; 13pt semibold title, 11pt tertiary count, 12pt in", token: "LayoutTokens.ToolTab.paneHeaderHeight"),
                .init(label: "Agent Jobs status column", value: "30pt", token: "LayoutTokens.AgentJobs.statusColumnWidth"),
            ],
            rules: [
                .init(text: "One header for every tool tab (TT2)", why: "The tool's icon, title, server and freshness, with its actions on the right: every tool reads the same."),
                .init(text: "Panes are cards (TT1)", why: "The same cards as the editor and results, a gutter apart, so a tool tab belongs to the window."),
                .init(text: "One header line: the tool's controls beside its name (round 37.2, UH5)", why: "With the pages in the tab, the second row only held a few buttons; on the header line every tool loses 40pt and reads the same.",
                      rounds: ["ongoing.tool-tab-header-r37"]),
                .init(text: "The controls are 28pt glass (round 37.3)", why: "The editor's design language: a glass main action, the others in one capsule, picker pills, a search capsule.",
                      rounds: ["ongoing.tool-tab-controls-r37"]),
                .init(text: "Five families, one theme (round 37.1)", why: "Monitor, Manage, Health, Properties and Canvas each have one layout idea; every tool shares the header, cards, tables and empty states.",
                      rounds: ["ongoing.tool-tab-families-r37", "ongoing.tool-tab-themes-r37"]),
                .init(text: "Every tab's own buttons in the window toolbar, tied to the tab (round 37.5)", why: "The owner: one place for every tab's dedicated buttons, as real toolbar buttons; replaces round 45. The tab's symbol in front was tried and removed.",
                      rounds: ["ongoing.tool-tab-toolbar-r37"]),
                .init(text: "A pane that compares two things of one object keeps them in one card", why: "A session's events and targets, or source and target DDL, are one subject."),
                .init(text: "Every Monitor opens on tiles (TT3, round 37.4)", why: "The key figures first, the detail below: Activity Monitor, SQL Profiler and Extended Events."),
                .init(text: "Configuration stays in the tab", why: "Read-only detail, such as a job's history, may use the Inspector."),
                .init(text: "One pane header for every pane (round 33)", why: "Headers in different sizes and places made the panes look unfinished; one 36pt line with title, count and actions lines them up.",
                      rounds: ["ongoing.agent-jobs-tab-r33"]),
                .init(text: "Lists end where their rows end (round 33)", why: "Stripes under the last row look like rows waiting to load.", rounds: ["ongoing.agent-jobs-tab-r33"]),
            ],
            code: [header, container, controls, tabToolbar, family, split, tiles, paneHeader, jobs, "Design/05-components.md › Tool tabs"]
        ) {
            ToolTabsSpecimen()
        },
        spec: ToolTabsSpec.spec(stageHeight: 380) { ToolTabsSpecimen() }
    )
}

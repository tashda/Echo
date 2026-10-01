import SwiftUI

/// Tool tabs by piece, each with a stable ID (`TLT-3.1`).
@MainActor
enum ToolTabsSpec {
    private static let header = "Echo/Sources/Shared/DesignSystem/Components/ToolTabHeader.swift"
    private static let container = "Echo/Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/ToolTabContainer.swift"
    private static let split = "Echo/Sources/Shared/DesignSystem/Components/CardSplitView.swift"
    private static let tiles = "Echo/Sources/Features/ActivityMonitor/Views/ActivityMonitorSparklineStrip.swift"
    private static let panels = "Echo/Sources/Shared/DesignSystem/Components/ContentPanelCards.swift"
    private static let paneHeader = "Echo/Sources/Shared/DesignSystem/Components/PaneHeader.swift"
    private static let jobs = "Echo/Sources/Features/AppHost/Views/Navigation/JobManagement"
    private static let controls = "Echo/Sources/Shared/DesignSystem/Components/ToolTabControls"
    private static let channel = controls + "/ToolTabHeaderContent.swift"
    private static let family = "Echo/Sources/Features/AppHost/Domain/ToolTabFamily.swift"
    private static let tabToolbar = "Echo/Sources/Shared/DesignSystem/Components/TabToolbar"

    static func spec<Specimen: View>(stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen) -> AreaSpec {
        AreaSpec(code: "TLT", stageHeight: stageHeight, parts: parts, specimen: specimen)
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Header", summary: "The one header every tool tab starts with (TT2), on one line with the tool's controls (round 37.2, UH5).", elements: [
            SpecElement(number: "1.1", name: "Header", summary: "On the canvas above the tool's cards, with no card of its own.", groups: [
                .layout(.row("Height", "40pt", token: "LayoutTokens.ToolTab.headerHeight"), .row("Padding", "8pt horizontal", token: "SpacingTokens.xs"),
                        .row("Spacing", "12pt between icon, text and actions", token: "SpacingTokens.sm")),
            ], files: [header, container]),
            SpecElement(number: "1.2", name: "Icon", summary: "The tool's symbol on a tinted tile.", groups: [
                .layout(.row("Symbol", "14pt semibold", token: "LayoutTokens.ToolTab.iconSize"), .row("Tile", "28pt", token: "iconBoxSize"),
                        .row("Corner", "7pt continuous", token: "iconCornerRadius")),
                .material(.row("Tile fill", "the tint at 12%", token: "TintedIcon.backgroundOpacity")),
            ], files: [header]),
            SpecElement(number: "1.3", name: "Title", summary: "The tool's name.", groups: [
                .type(.row("Font", "13pt semibold", token: "TypographyTokens.standard"), .row("Colour", "primary"), .row("Lines", "1")),
            ], files: [header]),
            SpecElement(number: "1.4", name: "Subtitle", summary: "The server, the database, and how fresh the data is.", groups: [
                .type(.row("Font", "11pt, tabular digits", token: "TypographyTokens.detail"), .row("Colour", "secondary"), .row("Lines", "1")),
                .behaviour(.row("Text", "server · database; a tool adds its freshness (\"updated 2 s ago\")"),
                           .row("Ticking", "live while the tab is on screen; frozen in a tab kept mounted behind another (SinceDateText, owner's choice 2026-10-01)")),
            ], files: [header, container]),
            SpecElement(number: "1.5", name: "Controls", summary: "The tool's pickers and search at the right of the same line (round 37.2); its buttons are in the window toolbar (TLT-10.3, round 37.5).", groups: [
                .layout(.row("Spacing", "8pt between controls", token: "SpacingTokens.xs"), .row("Glass", "one GlassEffectContainer around them")),
                .behaviour(.row("Set by", "the tool, from inside its content (toolTabHeaderControls); the innermost page wins"),
                           .row("Detail", "a tool can add one after the server: \"14 policies\", \"1,204 events\" (toolTabHeaderDetail)")),
            ], rounds: ["ongoing.tool-tab-header-r37"], files: [header, channel, container]),
        ]),
        SpecPart(number: "2", name: "Toolbar row", summary: "Gone (round 37.2): the controls are on the header line, the pages in the tab.", elements: [
            SpecElement(number: "2.1", name: "Toolbar row", summary: "A second row under the header for the tool's segmented control and buttons. Replaced by the header line (1.5) and the pages in the tab (TABS-5).", isRetired: true),
        ]),
        SpecPart(number: "3", name: "Dashboard tiles", summary: "Every Monitor opens on tiles (TT3, round 37.4 MO0): Activity Monitor, SQL Profiler and Extended Events.", elements: [
            SpecElement(number: "3.1", name: "Tile strip", summary: "The key figures, each on its own card, above the detail.", groups: [
                .layout(.row("Height", "76pt", token: "LayoutTokens.ToolTab.tileHeight"), .row("Gap", "the pane gutter", token: "workspaceGutter"),
                        .row("Padding", "12pt horizontal, 8pt vertical", token: "SpacingTokens.sm / xs")),
                .material(.row("Card", "the workspace card", token: "workspaceCard")),
            ], files: [tiles]),
            SpecElement(number: "3.2", name: "Tile content", summary: "A label, the current value large, and a sparkline of the recent history.", groups: [
                .type(.row("Label", "11pt secondary", token: "TypographyTokens.detail"), .row("Value", "large, tabular digits, with a small unit", token: "TypographyTokens.statNumber")),
                .layout(.row("Sparkline", "28pt high", token: "LayoutTokens.ToolTab.tileSparklineHeight")),
                .material(.row("Line", "the metric colour at 85%, 1.5pt"), .row("Fill", "the metric colour at 14%")),
                .behaviour(.row("No data", "an em dash in quaternary")),
            ], files: [tiles]),
        ]),
        SpecPart(number: "4", name: "Panes", summary: "Every pane is a card (TT1).", elements: [
            SpecElement(number: "4.1", name: "Pane card", summary: "The same card as the editor and results.", groups: [
                .material(.row("Card", "opaque workspace card", token: "adaptiveWorkspaceCard")),
                .layout(.row("Gap between panes", "4, 6 or 8pt (setting), 6 by default", token: "workspaceGutter")),
                .behaviour(.row("One-pane pages", "keep one card that steps aside when a page brings cards of its own")),
            ], files: [split, container]),
            SpecElement(number: "4.2", name: "Split", summary: "Two panes with a resizable gap.", groups: [
                .layout(.row("Minimum share", "20% (per tool)", token: "CardSplitView.minFraction")),
                .behaviour(.row("Drag the gap", "resizes"), .row("Second pane hidden", "the first takes all the room without being rebuilt")),
            ], files: [split]),
            SpecElement(number: "4.3", name: "Two things of one object", summary: "A session's events and targets, or the source and target DDL.", groups: [
                .behaviour(.row("Rule", "kept in one card")),
            ]),
        ]),
        SpecPart(number: "5", name: "Bottom panel", summary: "A tool's messages or live data.", elements: [
            SpecElement(number: "5.1", name: "Panel", summary: "Works like the query tab's results.", groups: [
                .behaviour(.row("Opens", "grows up out of the status bar and folds back into it"), .row("Resize", "drag the gap"),
                           .row("Maximise", "double-click the gap, or ⌥⇧⌘Y (View › Maximize Bottom Panel): a one-line content card stays"),
                           .row("Status bar", "floats in the content card while the panel is closed; rests on the canvas below cards side by side")),
                .motion(.row("Curve", "house spring out, smooth in, 0.45s")),
                .material(.row("Under the status bar", "a light card tint towards the bottom; only query tabs soften into the system's material (round 44, owner's note)", token: "ContentPanelCards.softensUnderFooter")),
            ], files: [panels]),
        ]),
        SpecPart(number: "6", name: "Pane header", summary: "The header at the top of a pane inside a tool tab's card (round 33, JH1).", elements: [
            SpecElement(number: "6.1", name: "Pane header", summary: "Every pane of a tool tab uses the same one, so the panes line up.", groups: [
                .layout(.row("Height", "36pt", token: "LayoutTokens.ToolTab.paneHeaderHeight"), .row("Padding", "12pt horizontal", token: "SpacingTokens.sm"),
                        .row("Spacing", "6pt between title and count", token: "SpacingTokens.xxs2")),
                .type(.row("Title", "13pt semibold, primary", token: "TypographyTokens.headline"),
                      .row("Count", "11pt tabular digits, tertiary", token: "TypographyTokens.detail")),
                .behaviour(.row("Actions", "the pane's own, at the right of the same line")),
            ], files: [paneHeader]),
        ]),
        SpecPart(number: "7", name: "Agent Jobs", summary: "SQL Server Agent's jobs, their details and their history (round 33).", elements: [
            SpecElement(number: "7.1", name: "Layout", summary: "Jobs the full height on the left; Details over History on the right (JL1).", groups: [
                .layout(.row("Jobs", "50% of the width, at least 25%", token: "CardSplitView.minFraction"),
                        .row("Details over History", "62% / 38%, each at least 20%")),
            ], files: ["\(jobs)/JobQueue/JobQueueView.swift"]),
            SpecElement(number: "7.2", name: "Jobs columns", summary: "Status, Name, Last Run, Next Run (JC1).", groups: [
                .layout(.row("Status", "30pt, one symbol", token: "LayoutTokens.AgentJobs.statusColumnWidth")),
                .material(.row("Ready", "checkmark.circle.fill, green"), .row("Failed last run", "xmark.circle.fill, red; Last Run in red"),
                          .row("Disabled", "pause.circle, tertiary; name dimmed, Next Run says Disabled")),
                .behaviour(.row("Owner and Category", "in Details › Properties")),
            ], files: ["\(jobs)/JobListView.swift", "\(jobs)/JobStatusSymbol.swift"]),
            SpecElement(number: "7.3", name: "A running job", summary: "A spinning symbol and its elapsed time in Last Run (JR1).", groups: [
                .material(.row("Symbol", "arrow.triangle.2.circlepath, orange, rotating")),
                .behaviour(.row("Last Run", "the time since the Agent started it, counting up, orange"),
                           .row("Polling", "every 2 s while any job runs; the list reloads when one finishes")),
            ], files: ["\(jobs)/JobQueue/JobQueueViewModel+Polling.swift", "\(jobs)/JobQueue/JobQueueViewModel+JobStatus.swift"]),
            SpecElement(number: "7.4", name: "Job actions", summary: "New Job and Start/Stop on the Jobs header; the rest in ⋯ and right-click (JA1).", groups: [
                .behaviour(.row("Header", "+ New Job; ▶ Start or ■ Stop for the selected job"),
                           .row("⋯", "Enable, Disable, New Alert, New Proxy, Manage Categories, Refresh"),
                           .row("Right-click", "Start or Stop, Enable, Disable; on empty space New Job and Refresh")),
            ], files: ["\(jobs)/JobListView+Actions.swift"]),
            SpecElement(number: "7.5", name: "Details sections", summary: "Properties, Steps, Schedules, Notifications: segmented, centred under the header (DT0).", groups: [
                .layout(.row("Gap below", "8pt", token: "SpacingTokens.xs")),
            ], files: ["\(jobs)/JobDetails/JobDetailsView.swift"]),
            SpecElement(number: "7.6", name: "Empty rows", summary: "No stripes: every list in the tab ends where its rows end (ER1).", groups: [
                .material(.row("Rows", "inset style, alternating backgrounds off")),
            ], files: ["\(jobs)/JobHistoryView.swift", "\(jobs)/JobDetails/JobDetailsView+Steps.swift"]),
            SpecElement(number: "7.7", name: "New Step and Edit Step", summary: "The command at the left, the settings at the right (round 33.2, NS4).", groups: [
                .layout(.row("Size", "760 by 480pt at least", token: "LayoutTokens.AgentJobs.stepSheetMinWidth / stepSheetMinHeight"),
                        .row("Sidebar", "300pt, the canvas colour, small controls", token: "LayoutTokens.AgentJobs.stepSidebarWidth"),
                        .row("Title", "\"New Step · Nightly\", centred; Edit Step adds \"Last run 26 Sep 23:00 · Succeeded · 14 min\" (ES1)", token: "AgentJobStepLastRun")),
                .behaviour(.row("Command", "Echo's SQL editor for T-SQL; Parse checks it without running it and marks the failing line (CE2)", token: "scripts.parse"),
                           .row("When it finishes", "On success, On failure (next step, quit with success or failure, step N), Retry attempts and interval (OC1)", token: "AgentJobStepOutcome"),
                           .row("Edit Step", "name and type shown, not editable: the driver can't rename a step or change its type"),
                           .row("Edges and button", "one surface, no hairline (SE1); Add Step prominent while it can be pressed (PB1)", token: "SheetLayout.primaryButton")),
            ], files: ["\(jobs)/Sheets/AgentJobStepEditorSheet.swift", "\(jobs)/Sheets/AgentJobStepEditorSheet+Sidebar.swift",
                       "\(jobs)/Sheets/AgentJobStepEditorSheet+Command.swift", "\(jobs)/AgentJobStepOutcome.swift"]),
            SpecElement(number: "7.8", name: "Header and window", summary: "The sidebar's Agent Jobs clock, in the jobs colour; Refresh on the header line.", groups: [
                .material(.row("Symbol", "clock, as the Agent Jobs folder in the tree", token: "ExplorerNodeKind.agentJobs.symbol"),
                          .row("Tint", "orange", token: "ColorTokens.Explorer.jobs")),
                .behaviour(.row("In its own window", "the window toolbar has Refresh and the inspector; Start/Stop and New Job stay on the Jobs pane (JA1)")),
            ], files: ["\(jobs)/JobQueue/JobQueueHeader.swift", "\(jobs)/JobQueueWindow.swift"]),
            SpecElement(number: "7.9", name: "Opening a step or a schedule", summary: "A double-click (or Return) opens Edit Step or Edit Schedule.", groups: [
                .behaviour(.row("Steps", "the right-click menu's first item is Edit Step"),
                           .row("Schedules", "Edit Schedule opens the schedule sheet on the schedule; it changes in place, so every job it is attached to follows", token: "AgentJobScheduleFields"),
                           .row("Not editable", "monthly-relative, Agent-start and idle schedules: Edit Schedule is dimmed")),
            ], files: ["\(jobs)/JobDetails/JobDetailsView+Steps.swift", "\(jobs)/JobDetails/JobDetailsView+Schedules.swift"]),
        ]),
        SpecPart(number: "8", name: "Controls", summary: "The header line's controls, in the editor's glass language (round 37.3).", elements: [
            SpecElement(number: "8.1", name: "Main action", summary: "The tab's special button in the window toolbar: a glass capsule, its symbol in the accent colour, its word in grey (PA1, round 37.5 MA1).", groups: [
                .layout(.row("Height", "28pt", token: "LayoutTokens.ToolTab.controlHeight"), .row("Padding", "12pt horizontal", token: "SpacingTokens.sm")),
                .type(.row("Word", "13pt medium, secondary", token: "TypographyTokens.standard")),
                .behaviour(.row("Running", "Stop with a pulsing red dot (ST1), as SQL Profiler's Stop Trace"),
                           .row("More than one thing to make", "the same capsule opens a menu (Add › Primary Key, Unique, Check)"),
                           .row("Where", "the tab's section of the window toolbar (round 37.5, replacing 45)")),
            ], rounds: ["ongoing.tool-tab-controls-r37", "ongoing.tool-tab-toolbar-r37"], files: [tabToolbar + "/TabToolbarSlots.swift"]),
            SpecElement(number: "8.2", name: "Other actions", summary: "Symbols in the window toolbar, each group one native toolbar item sharing the system's glass (SA2, round 37.5); the title is the tooltip.", groups: [
                .layout(.row("Height", "28pt", token: "controlHeight"), .row("Spacing", "12pt", token: "SpacingTokens.sm")),
                .behaviour(.row("Refresh", "a spinner in its place while the tab reloads"), .row("A toggle that is on", "its symbol in the accent colour"),
                           .row("Menu", "a symbol that opens a menu, as Export")),
            ], rounds: ["ongoing.tool-tab-controls-r37", "ongoing.tool-tab-toolbar-r37"], files: [tabToolbar + "/TabToolbarSlots.swift"]),
            SpecElement(number: "8.3", name: "Picker", summary: "One glass pill: a symbol, the value and a chevron, opening a menu of the choices (PK1).", groups: [
                .layout(.row("Height", "28pt", token: "controlHeight")),
                .behaviour(.row("Database", "Maintenance's database, Profiler's All Databases, a schema, an interval")),
            ], rounds: ["ongoing.tool-tab-controls-r37"], files: [controls + "/ToolTabPickerPill.swift", controls + "/ToolTabDatabasePill.swift"]),
            SpecElement(number: "8.4", name: "Search", summary: "A glass capsule at the right of the line, before the actions (SF1).", groups: [
                .layout(.row("Height", "28pt", token: "controlHeight"), .row("Field", "140pt", token: "LayoutTokens.ToolTab.searchFieldWidth")),
                .behaviour(.row("Clear", "an × appears once something is typed")),
            ], rounds: ["ongoing.tool-tab-controls-r37"], files: [controls + "/ToolTabSearchField.swift"]),
        ]),
        SpecPart(number: "9", name: "Families", summary: "Every tab but the query editor and the psql console belongs to one of five families (round 37.1), each with its layout (37.4).", elements: [
            SpecElement(number: "9.1", name: "Families", summary: "Monitor, Manage, Health, Properties, Canvas.", groups: [
                .behaviour(.row("Monitor", "Activity Monitor, SQL Profiler, Extended Events"),
                           .row("Manage", "Agent Jobs, Server and Database Security, Policy Management, Availability Groups, Resource Governor, Extensions, Advanced Objects"),
                           .row("Health", "Maintenance (Query Store is its page), Tuning Advisor, Error Log"),
                           .row("Properties", "Server Properties, Table Structure, Extension Details"),
                           .row("Canvas", "Schema Diagram, Query Builder, Schema Diff"),
                           .row("One theme", "every one has the header (the structure editor, diagram and Agent Jobs included), pane cards, tables and empty states")),
            ], rounds: ["ongoing.tool-tab-families-r37"], files: [family]),
            SpecElement(number: "9.2", name: "Health findings", summary: "What is wrong first, worst first, each with its fix (HE0).", groups: [
                .material(.row("Problem", "xmark.octagon.fill, red"), .row("Warning", "exclamationmark.triangle.fill, orange"), .row("Fine", "checkmark.circle.fill, green")),
                .behaviour(.row("SQL Server", "no or an old full backup, no log backup in full recovery (Back Up Now); large indexes over 30% fragmented (Rebuild)"),
                           .row("PostgreSQL", "tables with many dead rows (Vacuum); long open transactions, connections, the cache"),
                           .row("Fix", "a glass capsule at the end of the row; a spinner while it runs")),
            ], rounds: ["ongoing.tool-tab-themes-r37"], files: [controls + "/HealthFinding.swift", "Echo/Sources/Features/Maintenance/Domain/MaintenanceHealthFindings.swift"]),
            SpecElement(number: "9.3", name: "Manage details", summary: "The selected item's details on a card beside the list (MA0).", groups: [
                .behaviour(.row("Built", "Agent Jobs (Details over History), Policy Management (condition, facet, mode, schedule, last run)")),
            ], rounds: ["ongoing.tool-tab-themes-r37"], files: ["Echo/Sources/Features/Maintenance/Views/PolicyDetailsPane.swift"]),
            SpecElement(number: "9.4", name: "Apply bar", summary: "A Properties tool's changes wait in a bar at the bottom of its card (PR0).", groups: [
                .layout(.row("Padding", "12pt horizontal, 8pt vertical", token: "SpacingTokens.sm / xs")),
                .behaviour(.row("Text", "\"3 changes\" or \"Unsaved changes\""), .row("Buttons", "an extra (Script), Revert, then Apply, prominent and the default"),
                           .row("Built", "the structure editor (Apply reviews the statements; ⇧⌘↩), MySQL's config file (Save)")),
            ], rounds: ["ongoing.tool-tab-themes-r37"], files: [controls + "/ToolTabApplyBar.swift", "Echo/Sources/Features/QueryWorkspace/Views/TableStructure/TableStructureApplyBar.swift"]),
            SpecElement(number: "9.5", name: "Canvas bar", summary: "Zoom, its percentage, fit and what to show, in one glass capsule floating at the bottom of the drawing (CA0).", groups: [
                .layout(.row("Height", "30pt", token: "LayoutTokens.ToolTab.canvasBarHeight"), .row("Gap below", "12pt", token: "SpacingTokens.sm")),
                .behaviour(.row("Zoom", "in 10% steps; a double-click on the percentage gives 100%"), .row("Built", "Schema Diagram, Query Builder")),
            ], rounds: ["ongoing.tool-tab-themes-r37"], files: [controls + "/CanvasFloatingBar.swift"]),
        ]),
        SpecPart(number: "10", name: "Window toolbar", summary: "Every tab's own buttons are in the window toolbar, tied to the tab in front (round 37.5, replacing round 45).", elements: [
            SpecElement(number: "10.1", name: "No tool group", summary: "Round 45 kept tool buttons out of the toolbar. Replaced by the tab's section (10.3).", isRetired: true),
            SpecElement(number: "10.2", name: "Open in New Window", summary: "Agent Jobs' one toolbar item: its own glass group at the start of the right-hand side.", groups: [
                .behaviour(.row("Shown", "only while Agent Jobs is the front tab", token: "WorkspaceToolbarContext.canOpenInWindow"),
                           .row("Why", "the owner, 2026-10-01: it moves the tab, so it belongs with the window, not in the tab's header")),
                .material(.row("Symbol", "rectangle.portrait.and.arrow.right")),
            ], files: ["Echo/Sources/Features/AppHost/Views/Toolbar/WorkspaceToolbarItems/OpenInWindowToolbarButton.swift"]),
            SpecElement(number: "10.3", name: "The tab's buttons", summary: "Native toolbar items at the right, before the window's icons: the tab's special button, then each group of its other buttons (round 37.5; no tab symbol, the owner after checking it in Echo).", groups: [
                .material(.row("Special button", "a toolbar button with its symbol and word (MA1); Stop with a pulsing dot while running"),
                          .row("Other buttons", "one toolbar item per group, sharing the system's glass; toggles and menus are the toolbar's own")),
                .layout(.row("Gap", "the toolbar's fixed spacer between items (GP0)")),
                .behaviour(.row("Set by", "the tab's content, as data (.tabToolbar(special:groups:)); the innermost page wins, so the special button follows the page"),
                           .row("Slots", "one for the special button, up to three groups; they only hide, so the toolbar is not rebuilt when tabs switch", token: "WorkspaceToolbarContext.hasTabSpecial / tabGroupCount"),
                           .row("No buttons", "nothing; only the window's icons (EM0)"),
                           .row("Pickers and search", "stay on the tool's header line (MV1, HL0)")),
            ], rounds: ["ongoing.tool-tab-toolbar-r37"], files: [tabToolbar + "/TabToolbarSlots.swift", tabToolbar + "/TabToolbarItem.swift"]),
            SpecElement(number: "10.4", name: "The query editor", summary: "Run in its own glass that turns red (round 24, RN0), then Format · Validate · Help · Plan and, for SQL Server, SQLCMD · Statistics, each a native group.", groups: [
                .behaviour(.row("Items", "their own toolbar items, hidden for other tabs")),
            ], rounds: ["ongoing.tool-tab-toolbar-r37"], files: ["Echo/Sources/Features/AppHost/Views/Toolbar/WorkspaceToolbarItems/QueryEditorExecutionToolbarControls.swift"]),
            SpecElement(number: "10.5", name: "Switching and narrow windows", summary: "The slots stay; their buttons change in place with the house spring, and slots a tab doesn't need melt away as macOS hides toolbar items. In a narrow window the window's icons stay and the tab's buttons give way first (NW1).", groups: [
                .motion(.row("Buttons", "house spring", token: "EchoMotion.standard"), .row("Slots", "the system's hide and show")),
                .behaviour(.row("Narrow", "the window's group is kept out of overflow (visibilityPriority high, macOS 26.1)")),
            ], rounds: ["ongoing.tool-tab-toolbar-r37"], files: ["Echo/Sources/Features/AppHost/Views/Toolbar/WorkspaceToolbarItems/WorkspaceToolbarItems.swift"]),
        ]),
    ]
}

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

    static func spec<Specimen: View>(stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen) -> AreaSpec {
        AreaSpec(code: "TLT", stageHeight: stageHeight, parts: parts, specimen: specimen)
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Header", summary: "The one header every tool tab starts with (TT2).", elements: [
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
            SpecElement(number: "1.5", name: "Actions", summary: "The tool's own actions at the right.", groups: [
                .behaviour(.row("Placement", "trailing, in the tool's own controls")),
            ], files: [header]),
        ]),
        SpecPart(number: "2", name: "Toolbar row", summary: "The tool's controls, under the header.", elements: [
            SpecElement(number: "2.1", name: "Toolbar row", summary: "On the canvas, lined up with the header, once the panes are cards.", groups: [
                .behaviour(.row("Placement", "under the header, on the canvas"), .row("Why", "a toolbar inside a card would double the chrome")),
            ], files: [container]),
        ]),
        SpecPart(number: "3", name: "Dashboard tiles", summary: "Monitoring tools open on tiles (TT3).", elements: [
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
        ]),
    ]
}

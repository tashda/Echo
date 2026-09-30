import SwiftUI

/// Tool tabs by piece, each with a stable ID (`TLT-3.1`).
@MainActor
enum ToolTabsSpec {
    private static let header = "Echo/Sources/Shared/DesignSystem/Components/ToolTabHeader.swift"
    private static let container = "Echo/Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/ToolTabContainer.swift"
    private static let split = "Echo/Sources/Shared/DesignSystem/Components/CardSplitView.swift"
    private static let tiles = "Echo/Sources/Features/ActivityMonitor/Views/ActivityMonitorSparklineStrip.swift"
    private static let panels = "Echo/Sources/Shared/DesignSystem/Components/ContentPanelCards.swift"

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
                .behaviour(.row("Text", "server · database; a tool adds its freshness (\"updated 2 s ago\")")),
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
    ]
}

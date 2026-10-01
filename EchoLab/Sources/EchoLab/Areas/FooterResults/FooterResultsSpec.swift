import SwiftUI

/// The footer and results by piece, each with a stable ID (`FTR-2.4`). Values come from
/// `LayoutTokens.Footer`, `LayoutTokens.EdgeBlur`, `BottomPanelStatusBar` and the results grid.
@MainActor
enum FooterResultsSpec {
    private static let bar = "Echo/Sources/Shared/DesignSystem/Components/BottomPanelStatusBar.swift"
    private static let switcher = "Echo/Sources/Shared/DesignSystem/Components/DatabaseSwitcherCard.swift"
    private static let blur = "Echo/Sources/Shared/DesignSystem/Components/BackdropEdgeBlur.swift"
    private static let panels = "Echo/Sources/Shared/DesignSystem/Components/ContentPanelCards.swift"
    private static let grid = "Echo/Sources/Features/QueryWorkspace/Views/Results/NativeTable/"
    private static let r9 = "decided.round9-footer-scroller-tabs"
    private static let r10 = "decided.round10-footer-and-switcher"

    static func spec<Specimen: View>(stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen) -> AreaSpec {
        AreaSpec(code: "FTR", stageHeight: stageHeight, parts: parts, specimen: specimen)
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Results card", summary: "The card that grows up out of the footer when a query has results.", elements: [
            SpecElement(number: "1.1", name: "Open", summary: "The results grow up out of the footer.", groups: [
                .behaviour(.row("Run a query", "the editor card grows back to full height while the results card lands on its bottom edge"),
                           .row("Why", "it should look as if the footer itself expands; splitting the editor in place and a crossfade were rejected")),
                .motion(.row("Curve", "house spring", token: "echoMotion.standard"), .row("Duration", "0.45s")),
            ], rounds: [r10], files: [panels]),
            SpecElement(number: "1.2", name: "Close", summary: "They fold back into the footer.", groups: [
                .motion(.row("Curve", "smooth, no overshoot", token: "echoMotion.settle"), .row("Duration", "0.45s"),
                        .row("Card chrome", "fades out while it folds")),
            ], rounds: [r10], files: [panels]),
        ]),
        SpecPart(number: "2", name: "Footer", summary: "The floating strip at the bottom of the card.", elements: [
            SpecElement(number: "2.1", name: "Footer", summary: "Floats on the card rather than fixing to its edge (FP1).", groups: [
                .layout(.row("Height", "34pt", token: "LayoutTokens.Footer.height"), .row("Lift", "4pt above the bottom edge", token: "LayoutTokens.Footer.bottomLift"),
                        .row("Padding", "12pt on the sides, 8pt between items", token: "SpacingTokens.sm / xs")),
                .material(.row("Background", "none: no bar and no solid band")),
                .behaviour(.row("Empty space", "click to open or close the panel"), .row("Order", "chip · segments · mode chips · space · metrics")),
            ], rounds: [r9], files: [bar]),
            SpecElement(number: "2.2", name: "Soft blur behind", summary: "Rows scroll under the footer and blur away softly (FB1).", groups: [
                .material(.row("Blur radii", "1 · 3 · 6 · 10pt, strongest at the edge, a real blur of the AppKit content", token: "LayoutTokens.EdgeBlur.radii"),
                          .row("Fades beyond the footer", "16pt", token: "LayoutTokens.EdgeBlur.fade"),
                          .row("Step overlap", "30%", token: "LayoutTokens.EdgeBlur.step"),
                          .row("Card tint", "the card colour at 35%, a gradient growing towards the bottom, so the footer stays readable", token: "LayoutTokens.EdgeBlur.tintOpacity")),
                .behaviour(.row("SwiftUI content", "isn't blurred: only the grid and the editor")),
                .behaviour(.row("Why", "a hard edge left a solid band; a glass bar with glass pills inside would be glass on glass")),
            ], rounds: [r9], files: [blur]),
            SpecElement(number: "2.3", name: "Segments", summary: "One glass pill of icons beside the chip: Results, Messages, Execution Plan.", groups: [
                .material(.row("Glass", "one Liquid Glass capsule"), .row("Active", "a card-coloured capsule with a soft shadow", token: "ShadowTokens.railSelection")),
                .layout(.row("Segment", "28 × 20pt", token: "LayoutTokens.Footer.segmentWidth"), .row("Pill padding", "2pt", token: "LayoutTokens.Footer.pillPadding")),
                .type(.row("Icons", "11pt; primary when active, secondary otherwise", token: "TypographyTokens.detail")),
                .behaviour(.row("Click", "shows that panel; the one showing hides it"), .row("Tooltip", "Show or Hide, and the name"),
                           .row("Unavailable", "30% and disabled")),
                .motion(.row("Press", "0.16s", token: "echoMotion.press")),
            ], files: [bar]),
            SpecElement(number: "2.7", name: "Mode chips", summary: "Small labelled chips for a tab's mode, after the segments.", groups: [
                .material(.row("Fill", "hover fill on a capsule", token: "ColorTokens.Sidebar.hoverFill"), .row("Colour", "mode indicator", token: "ColorTokens.Status.modeIndicator")),
                .layout(.row("Height", "24pt", token: "LayoutTokens.Footer.chipHeight"), .row("Padding", "10pt")),
                .type(.row("Font", "11pt, an icon then the label")),
            ], files: [bar]),
            SpecElement(number: "2.4", name: "Server and database chip", summary: "Shows where the tab runs; click to switch database.", groups: [
                .material(.row("Glass", "Liquid Glass capsule; interactive when the tab can switch database")),
                .layout(.row("Height", "24pt", token: "LayoutTokens.Footer.chipHeight"), .row("Horizontal padding", "10pt", token: "LayoutTokens.Footer.chipHorizontalPadding")),
                .type(.row("Font", "11pt primary: server · database, truncated in the middle", token: "TypographyTokens.detail")),
                .behaviour(.row("Click", "opens the database switcher"), .row("Can't switch", "disabled; the tooltip is the name"), .row("Tooltip", "Switch Database")),
            ], rounds: [r10], files: [bar]),
            SpecElement(number: "2.5", name: "Metric pills", summary: "A glass pill per entry at the right: status, selection summary, rows and time.", groups: [
                .material(.row("Glass", "one Liquid Glass pill per entry"), .row("Height", "the chip's, 24pt with 10pt padding", token: "LayoutTokens.Footer.chipHeight")),
                .layout(.row("Spacing", "4pt between pills", token: "SpacingTokens.xxs"), .row("Order", "selection summary, rows, time, then the status at the far right")),
                .type(.row("Selection summary", "11pt tabular digits, secondary"), .row("Rows", "the count in 11pt monospaced medium, its label tertiary"),
                      .row("Time", "11pt monospaced medium, secondary")),
                .behaviour(.row("Click", "opens or closes the panel, or toggles the statistics popover when the tab has one"),
                           .row("Why one each", "one big pill and plain text were rejected"), .row("Style", "pill per entry", token: "FooterMetricsStyle.pillPerEntry")),
            ], rounds: [r10], files: [bar]),
            SpecElement(number: "2.6", name: "Status", summary: "A dot and a word: Ready, Running, Error.", groups: [
                .type(.row("Font", "detail 11pt, secondary", token: "TypographyTokens.detail")),
                .states(.row("Dot", "the status colour; it pulses while the status says so", token: "PulsingStatusDot")),
            ], files: [bar]),
        ]),
        SpecPart(number: "3", name: "Database switcher", summary: "The card that rises above the chip.", elements: [
            SpecElement(number: "3.1", name: "Card", summary: "A filter field and the databases, above the chip so the chip stays visible.", groups: [
                .material(.row("Kind", "a system popover with its arrow at the top, so the glass, theming and dismissal are the system's")),
                .layout(.row("Width", "260pt", token: "LayoutTokens.FloatingSurface.smallWidth"), .row("Padding", "12pt", token: "LayoutTokens.FloatingSurface.padding"),
                        .row("Tallest list", "280pt, then it scrolls", token: "LayoutTokens.Footer.switcherListMaxHeight")),
                .behaviour(.row("Close", "Esc or a click away"), .row("Rejected", "a native menu, and picking the database in the tree")),
            ], rounds: [r10], files: [switcher]),
            SpecElement(number: "3.2", name: "Filter field", summary: "At the top of the card; focused as it opens.", groups: [
                .layout(.row("Height", "28pt", token: "LayoutTokens.FloatingSurface.rowHeight"), .row("Corner", "10pt", token: "rowCornerRadius")),
                .type(.row("Font", "small caption", token: "TypographyTokens.caption2"), .row("Prompt", "Filter N databases")),
                .material(.row("Fill", "hover fill", token: "ColorTokens.Sidebar.hoverFill")),
                .behaviour(.row("↑ ↓", "move the highlight"), .row("Return", "picks the highlighted database, or the first match")),
            ], files: [switcher]),
            SpecElement(number: "3.3", name: "Database row", summary: "A cylinder, the name, and a check on the current one.", groups: [
                .layout(.row("Height", "28pt", token: "LayoutTokens.FloatingSurface.rowHeight"), .row("Corner", "10pt")),
                .material(.row("Highlight", "selected fill on the highlighted row (also under the pointer)", token: "ColorTokens.Sidebar.selectedFill"),
                          .row("Icon and check", "accent", token: "ColorTokens.accent")),
                .behaviour(.row("No match", "\"No matching databases\" in secondary")),
            ], files: [switcher]),
        ]),
        SpecPart(number: "4", name: "Results grid", summary: "The table of results.", elements: [
            SpecElement(number: "4.1", name: "Cells", summary: "Proportional text; monospaced is a setting.", groups: [
                .type(.row("Font", "12pt", token: "ResultsGridMetrics.cellFontSize"), .row("Monospaced cells", "a setting, off by default", token: "resultsMonospacedCells")),
                .layout(.row("Side padding", "10pt", token: "ResultsGridMetrics.contentHorizontalPadding"), .row("Column width", "56 to 420pt, sized from the first 200 rows", token: "minimumColumnWidth / maximumColumnWidth")),
                .behaviour(.row("Numbers and dates", "right-aligned with tabular digits"), .row("Booleans", "✓ or ✗, centred"),
                           .row("NULL", "italic grey text"), .row("Copy and export", "use the raw values")),
            ], rounds: ["decided.results-grid"], files: [grid + "ResultCellPresentation.swift", grid + "ResultsGridMetrics.swift"]),
            SpecElement(number: "4.2", name: "Column header", summary: "The column's name over its type, on two lines.", groups: [
                .type(.row("Name", "12pt semibold"), .row("Type", "10pt monospaced, under the name")),
                .layout(.row("Height", "36pt", token: "ResultsGridMetrics.headerHeight")),
                .behaviour(.row("Sort arrow", "a 14pt box at the trailing edge, shown while hovered or sorted; click it to sort, click elsewhere to select the column",
                                token: "ResultsGridMetrics.sortIndicatorSize")),
            ], rounds: ["decided.results-grid"], files: [grid + "Cells/ResultTableHeaderCell.swift", grid + "Cells/ResultTableHeaderView.swift"]),
            SpecElement(number: "4.3", name: "Row hover", summary: "A faint rounded tint on the row under the pointer.", groups: [
                .material(.row("Fill", "hover fill", token: "ColorTokens.Sidebar.hoverFill")),
                .layout(.row("Inset", "2pt by 1pt", token: "ResultsGridMetrics.hoverHorizontalInset / hoverVerticalInset"), .row("Corner", "5pt", token: "ResultsGridMetrics.hoverCornerRadius")),
                .behaviour(.row("Row number", "turns accent")),
            ], rounds: ["decided.results-grid"], files: [grid + "Cells/ResultTableRowView.swift"]),
            SpecElement(number: "4.4", name: "Selection", summary: "One rounded outline around the selected range and a stronger ring on the active cell.", groups: [
                .material(.row("Range", "accent at 18%, outlined 1pt at 65%: each row strokes its sides and only the first and last close it, so there are no seams"),
                          .row("Active cell", "accent ring, 2pt, 4pt corner", token: "ResultsGridMetrics.activeCellRingWidth / activeCellCornerRadius")),
                .behaviour(.row("Row numbers", "of the selected rows turn accent")),
            ], rounds: ["decided.results-grid"], files: [grid + "Cells/ResultTableRowView.swift", grid + "Cells/ResultTableRowNumberView.swift"]),
            SpecElement(number: "4.5", name: "Row numbers", summary: "A column of monospaced numbers at the left.", groups: [
                .type(.row("Font", "12pt monospaced digits", token: "ResultsGridMetrics.rowNumberFontSize")),
                .layout(.row("Width", "at least 6 digits", token: "ResultsGridMetrics.minimumRowNumberDigits"), .row("Padding", "2pt leading, 5pt trailing")),
            ], files: [grid + "Cells/ResultTableRowNumberView.swift"]),
            SpecElement(number: "4.6", name: "Scroll bars", summary: "Overlay bars that stop above the footer; round 27 asks where they belong.", groups: [
                .layout(.row("Horizontal", "floats over the last rows, its bottom at the footer's top (footer height + lift)", token: "LayoutTokens.Footer.height + bottomLift"),
                        .row("Vertical", "ends at the same height"),
                        .row("Rows", "scroll clear of the footer by the same inset")),
                .behaviour(.row("Shown", "while scrolling, as the system's overlay bars")),
            ], files: [grid + "ResultTableContainerView.swift"]),
        ]),
    ]
}

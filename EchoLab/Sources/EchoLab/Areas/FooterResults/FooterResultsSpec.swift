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
                .material(.row("Blur radii", "4 · 4.25 · 4.5 · 5 · 5.25 · 5.5pt, stacked so the blur grows evenly from sharp to about 12pt at the edge, a real blur of the AppKit content (owner, after round 27: the old 0.75 to 10pt steps jumped within one row and read as a line)", token: "LayoutTokens.EdgeBlur.radii"),
                          .row("Fades beyond the footer", "24pt (round 27, was 16)", token: "LayoutTokens.EdgeBlur.fade"),
                          .row("Step fade", "90% of each step's reach, along an S curve, so the steps overlap", token: "LayoutTokens.EdgeBlur.step"),
                          .row("Card tint", "the card colour at 35%, a gradient growing towards the bottom, so the footer stays readable", token: "LayoutTokens.EdgeBlur.tintOpacity")),
                .behaviour(.row("SwiftUI content", "isn't blurred: only the grid and the editor"),
                           .row("Where it lives", "in the scroll view's clip view, under the scroll bars, following the visible area (round 27)")),
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
            SpecElement(number: "2.6", name: "Status", summary: "A dot and a word: Ready, Running, Error; or an icon and a word in a tint.", groups: [
                .type(.row("Font", "detail 11pt, secondary", token: "TypographyTokens.detail"),
                      .row("With an icon", "the icon 11pt semibold and the word both in the tint (round 21, TL2)")),
                .states(.row("Dot", "the status colour; it pulses while the status says so", token: "PulsingStatusDot"),
                        .row("Icon", "replaces the dot, e.g. an open transaction (round 21, TL2)"),
                        .row("Time since", "m:ss in monospaced digits after the word, once a minute has passed (round 21, TT2)")),
                .behaviour(.row("Menu", "when the status has actions, clicking it opens them (round 21, TA2)"),
                           .row("Tooltip", "who holds a lock, or another hint (round 21, LF3)")),
            ], rounds: ["ongoing.pg-transaction-state-r21"], files: [bar, "Echo/Sources/Shared/DesignSystem/Components/BottomPanelStatusBar+Metrics.swift"]),
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
                .behaviour(.row("No match", "\"No matching databases\" in secondary"),
                           .row("Scrolling", "the list scrolls to the highlighted row only when the arrow keys or the filter move it; the pointer highlights without scrolling (owner, 2026-10-01: it followed the pointer)")),
            ], files: [switcher]),
        ]),
        SpecPart(number: "4", name: "Results grid", summary: "The table of results.", elements: [
            SpecElement(number: "4.1", name: "Cells", summary: "Proportional text; monospaced is a setting.", groups: [
                .type(.row("Font", "12pt", token: "ResultsGridMetrics.cellFontSize"), .row("Monospaced cells", "a setting, off by default", token: "resultsMonospacedCells")),
                .layout(.row("Side padding", "10pt", token: "ResultsGridMetrics.contentHorizontalPadding"), .row("Column width", "56 to 420pt, sized from the first 200 rows", token: "minimumColumnWidth / maximumColumnWidth")),
                .behaviour(.row("Numbers and dates", "right-aligned with tabular digits"), .row("Booleans", "✓ or ✗, centred"),
                           .row("NULL", "italic grey text"), .row("Copy and export", "use the raw values"),
                           .row("Decimals", "lined up on the decimal point, padded to the column's widest fraction, at most 6 digits (round 21, VN2)", token: "ResultCellValueForm.maxAlignedFractionDigits"),
                           .row("PostgreSQL arrays", "the element count in secondary, then the elements without braces or quotes (VA4)"),
                           .row("JSON", "{ 4 keys } or [ 12 items ] (VJ3)"), .row("Binary", "its kind and size (VB3)"),
                           .row("Copy as Shown", "copies what the cells draw; plain Copy keeps the server's text")),
            ], rounds: ["decided.results-grid", "ongoing.pg-value-display-r21", "ongoing.mssql-values-r22"],
               files: [grid + "ResultCellPresentation.swift", grid + "ResultsGridMetrics.swift", grid + "ResultCellValueForm.swift"]),
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
            SpecElement(number: "4.6", name: "Scroll bars", summary: "The system's bar on the footer's top edge, as wide as the footer; the blur rises past it while it shows.", groups: [
                .layout(.row("Horizontal", "its thumb ends 42pt above the card's edge: 9pt above the footer's pills, the gap the pills keep above the edge", token: "LayoutTokens.Footer.scrollBarBottom"),
                        .row("Length", "as wide as the footer: from its left padding, over the row numbers, to its right padding (round 27, L2)", token: "SpacingTokens.sm"),
                        .row("How", "the footer's room as the content inset, and a 1pt scroller inset on top (AppKit adds them; the thumb sits 3pt inside its frame)", token: "LayoutTokens.Footer.scrollerInset(overFooter:)"),
                        .row("Vertical", "runs down to the horizontal bar"),
                        .row("Soft edges", "the rows fade 32pt into the card's colour at a side where more columns wait", token: "LayoutTokens.EdgeBlur.sideFadeWidth")),
                .material(.row("Look", "the system's overlay bar, no track (T1)")),
                .motion(.row("Blur rises", "while the bar shows, the blur rises past its widest thumb in 0.32s and settles 0.9s after the last scroll, in 0.5s (U5); only the blur's masks move, on the render server", token: "LayoutTokens.EdgeBlur.raiseDuration / settleDuration / raisedHold")),
                .behaviour(.row("Shown", "while scrolling, as macOS does"),
                           .row("Under the footer", "the bars sit above the footer's blur, which lives in the clip view under them"),
                           .row("Everywhere", "every overlay horizontal bar in Echo gets the same rising blur, SwiftUI tables included (ScrollBarBlur, installed once at launch)"),
                           .row("Same footer placement", "the editor, Messages and Extended Events place their bars the same way (footerScrollRoom for SwiftUI)")),
            ], rounds: ["ongoing.results-scrollers-r27"],
               files: [grid + "ResultTableContainerView.swift", "Echo/Sources/Shared/DesignSystem/Components/FooterScrollOverlay.swift",
                       "Echo/Sources/Shared/DesignSystem/Components/ScrollBarBlur.swift", "Echo/Sources/Shared/DesignSystem/Components/ScrollSideFades.swift",
                       "Echo/Sources/Shared/DesignSystem/Components/FooterScrollRoom.swift"]),
        ]),
    ]
}

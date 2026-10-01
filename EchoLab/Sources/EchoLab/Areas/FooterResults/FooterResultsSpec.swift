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
    private static let r41Header = "ongoing.results-header-lines-r41"
    private static let r41Selection = "ongoing.results-selection-summary-r41"
    private static let r41Error = "ongoing.results-error-page-r41"
    private static let r41Messages = "ongoing.results-messages-r41"
    private static let r41Pills = "ongoing.results-pill-popovers-r41"
    private static let section = "Echo/Sources/Features/QueryWorkspace/Views/Results/Section/"
    private static let popovers = section + "FooterPopovers/"
    private static let console = "Echo/Sources/Features/QueryWorkspace/Views/Results/ExecutionConsole/"

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
            SpecElement(number: "1.3", name: "State banner", summary: "What the card says when it has no rows: a banner at the top left (round 41.3, EP1).", groups: [
                .layout(.row("Place", "top left of the card, 16pt padding; symbol, then title and detail, then chips and actions", token: "SpacingTokens.md"),
                        .row("Symbol", "title 3, in the state's tint; a small spinner while running", token: "TypographyTokens.title3")),
                .type(.row("Title", "13pt semibold", token: "TypographyTokens.standard"), .row("Detail", "13pt secondary, selectable")),
                .states(.row("Failed", "red octagon, \"Failed on line 7\", the message; SQL Server's Msg · Level · State as quiet chips (ED0)", token: "ColorTokens.Sidebar.hoverFill"),
                        .row("Running", "spinner, \"Running\", Waiting for the first rows."), .row("No rows", "\"No rows\" and the command tag, or The query ran and returned nothing."),
                        .row("Cancelled", "orange stop, \"Cancelled\", You stopped the query after 4 s.")),
                .behaviour(.row("Actions on a failure", "Show in Editor (default), Messages, Copy Error, small (EA1); Copy Error copies the numbers' line and the message"),
                           .row("In the editor", "unchanged: the red pill on the statement's first word (HL0)"),
                           .row("Rejected", "the centred poster (EP0), no page (EP2), the Messages row (EP3)")),
            ], rounds: [r41Error], files: [section + "ResultsStateBanner.swift", section + "QueryFailureView.swift"]),
        ]),
        SpecPart(number: "2", name: "Footer", summary: "The floating strip at the bottom of the card.", elements: [
            SpecElement(number: "2.1", name: "Footer", summary: "Floats on the card rather than fixing to its edge (FP1).", groups: [
                .layout(.row("Height", "34pt", token: "LayoutTokens.Footer.height"), .row("Lift", "4pt above the bottom edge", token: "LayoutTokens.Footer.bottomLift"),
                        .row("Padding", "12pt on the sides, 8pt between items", token: "SpacingTokens.sm / xs")),
                .material(.row("Background", "none: no bar and no solid band")),
                .behaviour(.row("Empty space", "click to open or close the panel"), .row("Order", "chip · segments · mode chips · space · metrics")),
            ], rounds: [r9], files: [bar]),
            SpecElement(number: "2.2", name: "Soft blur behind", summary: "Rows scroll under the footer and soften into the system's material (FB1, round 44).", groups: [
                .material(.row("Material", "the system's ultra-thin material (BT4); stacked blur steps, one Core Image variable blur and a plain fade were not chosen"),
                          .row("Reach", "the footer and 40pt above it (BH3)", token: "LayoutTokens.EdgeBlur.materialReach"),
                          .row("Fade", "from clear at the top to full at the card's edge, (e^(4.5t) − 1) / (e^4.5 − 1): half way up it is only 10%, so no row meets it at once (CV6)", token: "LayoutTokens.EdgeBlur.materialGrowth"),
                          .row("Card tint", "the card colour at 15% over the material, faded the same way (TT1)", token: "LayoutTokens.EdgeBlur.materialTintOpacity")),
                .behaviour(.row("SwiftUI content", "softens too: it lies over whatever the card shows"),
                           .row("Where it lives", "behind the footer in the card (ContentPanelCards), over the grid and its scroll bars (round 44)")),
                .behaviour(.row("Why", "a hard edge left a solid band; a glass bar with glass pills inside would be glass on glass")),
            ], rounds: [r9, "ongoing.footer-blur-r44"], files: [blur, "Echo/Sources/Shared/DesignSystem/Components/FooterMaterialBlur.swift"]),
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
                .material(.row("Server dot", "with Server Header Color set to Server's Color, a 6pt dot of the server's colour before the name, 6pt from it (round 30.1, CO2)", token: "EnvironmentValues.serverPillColor")),
                .behaviour(.row("Click", "opens the database switcher"), .row("Can't switch", "disabled; the tooltip is the name"), .row("Tooltip", "Switch Database")),
            ], rounds: [r10], files: [bar]),
            SpecElement(number: "2.5", name: "Metric pills", summary: "A glass pill per entry at the right: status, selection summary, rows and time.", groups: [
                .material(.row("Glass", "one Liquid Glass pill per entry"), .row("Height", "the chip's, 24pt with 10pt padding", token: "LayoutTokens.Footer.chipHeight")),
                .layout(.row("Spacing", "4pt between pills", token: "SpacingTokens.xxs"), .row("Order", "selection summary, rows, time, then the status at the far right")),
                .type(.row("Selection summary", "11pt tabular digits, secondary"), .row("Rows", "the count in 11pt monospaced medium, its label tertiary"),
                      .row("Time", "11pt monospaced medium, secondary")),
                .behaviour(.row("Click", "a pill opens its own popover above it (round 41.5, PP2); a pill without one, or the space between, opens or closes the panel"),
                           .row("Why one each", "one big pill and plain text were rejected"), .row("Style", "pill per entry", token: "FooterMetricsStyle.pillPerEntry")),
            ], rounds: [r10, r41Pills], files: [bar, "Echo/Sources/Shared/DesignSystem/Components/BottomPanelStatusBar+Metrics.swift"]),
            SpecElement(number: "2.8", name: "Selection pill", summary: "The count, \"89 cells\", and by Setting the sum and/or average; the exact figures in its popover (round 41.2).", groups: [
                .type(.row("Pill", "11pt tabular digits, secondary: \"89 cells\" (SP3)"),
                      .row("Setting", "Settings › Results › Selection summary: Count (default), Count and sum, Count and average, Count, sum and average, in the locale's short form: \"89 cells · Sum 34.6T · Avg 389B\"; text stays a count", token: "GlobalSettings.resultsSelectionPill")),
                .layout(.row("Popover", "260pt: the title (\"89 cells in bagno\" for one column) and Copy All, then a line per figure", token: "LayoutTokens.FloatingSurface.smallWidth")),
                .behaviour(.row("Figures, numbers", "Count, Sum, Average, Min, Max, Median, Distinct, Empty (FG1); exact, with the selection's decimals", token: "GridSelectionSummary.figures"),
                           .row("Figures, text", "Count, Distinct, Empty (TX0)"), .row("Copy", "a Copy button on the line under the pointer; Copy All as label–tab–value lines (PO1)"),
                           .row("Shown", "for two cells or more; over 50,000 cells only counted", token: "GridSelectionSummary.maximumSummedCells")),
            ], rounds: [r41Selection], files: [popovers + "SelectionSummaryPopover.swift", popovers + "FooterPopoverContent.swift"]),
            SpecElement(number: "2.9", name: "Rows popover", summary: "What the rows are and what to do with them (round 41.5, PR0).", groups: [
                .layout(.row("Width", "260pt", token: "LayoutTokens.FloatingSurface.smallWidth"), .row("Title", "1,204 rows · 3 columns")),
                .behaviour(.row("Lines", "Result 1 of 3 (with several sets), Loaded 1,204 of 1,204, In memory"), .row("Actions", "none: exporting and copying results is the grid's right-click menu (Copy, Copy with Headers, Copy as Shown, Copy As, Save As, Select All)")),
            ], rounds: [r41Pills], files: [popovers + "RowsPillPopover.swift"]),
            SpecElement(number: "2.10", name: "Time popover", summary: "Where the time went (round 41.5, PT0).", groups: [
                .layout(.row("Width", "320pt", token: "LayoutTokens.FloatingSurface.mediumWidth"), .row("Bar", "8pt capsule: sending (tertiary), waiting for the first row (orange), reading rows (accent)", token: "QueryRunTimeline")),
                .behaviour(.row("Lines", "Started, Finished, Last runs (this tab's previous runs, newest first, up to 4)"), .row("Actions", "none (no Run Again)"),
                           .row("Not yet", "server CPU: Echo doesn't get it from the drivers")),
            ], rounds: [r41Pills], files: [popovers + "TimePillPopover.swift"]),
            SpecElement(number: "2.11", name: "Status popover", summary: "What happened and when, and what to do next (round 41.5, PS0).", groups: [
                .layout(.row("Width", "320pt", token: "LayoutTokens.FloatingSurface.mediumWidth"), .row("Title", "Completed at 15:34:51, Failed on line 7, Running, Cancelled at …")),
                .behaviour(.row("Lines", "the error message, Transaction (None open, Open since, Failed), Messages (count)"),
                           .row("Actions", "Cancel while running; Commit and Roll Back in a transaction (round 21, TA2, now in the popover); Show in Editor after an error. No Messages or Run Again (owner)"),
                           .row("Not yet", "the session (SPID): Echo doesn't get it from the drivers")),
            ], rounds: [r41Pills, "ongoing.pg-transaction-state-r21"], files: [popovers + "StatusPillPopover.swift"]),
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
                .material(.row("Line under it", "one hairline at the header's true bottom, level with the row-number column's: the header paints its full height in the card's colour and draws it, because the system's scroll pocket behind it stops about 4pt short of 36pt on macOS 26 (round 41.1, HL1, and the owner's note after)"),
                          .row("Column dividers", "short separators between columns, kept: they mark where to drag a width (VD0)", token: "NSColor.separatorColor")),
                .behaviour(.row("Sort arrow", "a 14pt box at the trailing edge, shown while hovered or sorted; click it to sort, click elsewhere to select the column",
                                token: "ResultsGridMetrics.sortIndicatorSize")),
            ], rounds: ["decided.results-grid", r41Header], files: [grid + "Cells/ResultTableHeaderCell.swift", grid + "Cells/ResultTableHeaderView.swift"]),
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
            SpecElement(number: "4.6", name: "Scroll bars", summary: "The system's bar on the footer's top edge, as wide as the footer, on the footer's material.", groups: [
                .layout(.row("Horizontal", "its thumb ends 42pt above the card's edge: 9pt above the footer's pills, the gap the pills keep above the edge", token: "LayoutTokens.Footer.scrollBarBottom"),
                        .row("Length", "as wide as the footer: from its left padding, over the row numbers, to its right padding (round 27, L2)", token: "SpacingTokens.sm"),
                        .row("How", "the footer's room as the content inset, and a 1pt scroller inset on top (AppKit adds them; the thumb sits 3pt inside its frame)", token: "LayoutTokens.Footer.scrollerInset(overFooter:)"),
                        .row("Vertical", "runs down to the horizontal bar"),
                        .row("Soft edges", "the rows fade 32pt into the card's colour at a side where more columns wait", token: "LayoutTokens.EdgeBlur.sideFadeWidth")),
                .material(.row("Look", "the system's overlay bar, no track (T1)")),
                .motion(.row("Blur rises", "under a footer, nothing rises: the footer's material already reaches past the bar (round 44); elsewhere, while the bar shows, the blur rises past its widest thumb in 0.32s and settles 0.9s after the last scroll, in 0.5s (U5)", token: "LayoutTokens.EdgeBlur.raiseDuration / settleDuration / raisedHold")),
                .behaviour(.row("Shown", "while scrolling, as macOS does"),
                           .row("Under the footer", "the footer's material lies over the bars too, at about 6% where they are, so they stay clear"),
                           .row("Everywhere", "every other overlay horizontal bar in Echo gets the rising blur, SwiftUI tables included (ScrollBarBlur, installed once at launch)"),
                           .row("Same footer placement", "the editor, Messages and Extended Events place their bars the same way (footerScrollRoom for SwiftUI)")),
            ], rounds: ["ongoing.results-scrollers-r27"],
               files: [grid + "ResultTableContainerView.swift", "Echo/Sources/Shared/DesignSystem/Components/FooterScrollOverlay.swift",
                       "Echo/Sources/Shared/DesignSystem/Components/ScrollBarBlur.swift", "Echo/Sources/Shared/DesignSystem/Components/ScrollSideFades.swift",
                       "Echo/Sources/Shared/DesignSystem/Components/FooterScrollRoom.swift"]),
        ]),
        SpecPart(number: "5", name: "Messages", summary: "What the server said, by statement (round 41.4).", elements: [
            SpecElement(number: "5.1", name: "Top", summary: "No strip: the counts, which filter, and a ⋯ menu (MT1).", groups: [
                .type(.row("Counts", "11pt: \"1 error\" semibold red, \"2 warnings\" orange, \"3 messages\" secondary; only those there are", token: "TypographyTokens.detail")),
                .behaviour(.row("Click a count", "shows only those, on a selected capsule; click again for all", token: "ColorTokens.Sidebar.selectedFill"),
                           .row("⋯ menu", "Copy All Messages, Clear Messages")),
            ], rounds: [r41Messages], files: [console + "ExecutionConsoleView+Counts.swift"]),
            SpecElement(number: "5.2", name: "Statement groups", summary: "Each statement a heading, its messages under it (ML1).", groups: [
                .type(.row("Heading", "\"Line 7\" 11pt semibold, the statement's first line 11pt monospaced, both secondary; the time at the right, tertiary")),
                .layout(.row("Messages", "12pt in from the heading", token: "SpacingTokens.sm"), .row("Between groups", "8pt", token: "SpacingTokens.xs")),
                .behaviour(.row("Line 7", "puts the editor on that line"), .row("Scripts", "a PostgreSQL script's statements each head their own line"),
                           .row("No statement", "a connection's or a maintenance task's messages have no heading")),
            ], rounds: [r41Messages], files: [console + "ExecutionConsoleView.swift", console + "ExecutionConsoleView+Messages.swift", "Echo/Sources/Features/QueryWorkspace/Domain/QueryMessageStatement.swift"]),
            SpecElement(number: "5.3", name: "Message", summary: "A symbol and the text; errors red symbol, semibold text, no fill (EE1).", groups: [
                .type(.row("Text", "13pt primary; an error's semibold", token: "TypographyTokens.standard"),
                      .row("SQL Server's numbers", "under an error: Msg 248, Level 16, State 1, Line 7 in 11pt tertiary, the line a link (EM1, LL1)")),
                .behaviour(.row("Symbol", "for a message from the server it opens \"From the server\": number, level, state, line, procedure and server (SQL Server), other fields the driver passed on (PostgreSQL's SQLSTATE, detail, hint) and the text as sent, with Copy; Echo's own lines have a plain symbol", token: "ServerMessagePopover"),
                           .row("Time", "on hover"), .row("Gone", "the category and delta columns, Echo's own started/finished/failed lines (EM0), the execution metrics row (DM1: in the time popover)")),
            ], rounds: [r41Messages], files: [console + "ExecutionConsoleView+Messages.swift", console + "ServerMessagePopover.swift"]),
        ]),
    ]
}

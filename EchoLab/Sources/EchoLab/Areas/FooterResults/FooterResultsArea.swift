import SwiftUI

/// The results card and its footer as they are in Echo today (rounds 9 and 10, plan Phase 12).
@MainActor
enum FooterResultsArea {
    static let area = LabArea(
        id: "footer-results",
        title: "Footer and results",
        symbol: "tablecells",
        summary: "The results grow up out of the footer. The footer floats on a soft blur with a glass pill per entry; the database switcher is a card above its chip.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "6e4a0e60", date: "2026-10-01",
                note: "Read from BottomPanelStatusBar (+Metrics), DatabaseSwitcherCard, BackdropEdgeBlur, ContentPanelCards, ResultsGridMetrics, ResultTableRowView, ResultTableHeaderCell/View, ResultCellPresentation, the results Section (state banner, footer popovers), ExecutionConsoleView and the Footer and EdgeBlur tokens. The specimen uses Echo Labs' copy of BottomPanelStatusBar over a sample grid (its pills don't open popovers)."),
            stageHeight: 480,
            behaviours: [
                .init(trigger: "Run a query", result: "The results grow up out of the footer: the editor card grows back to full height while the results card lands on its bottom edge."),
                .init(trigger: "Close the results", result: "They fold back into the footer smoothly, the card's chrome fading out."),
                .init(trigger: "Click a segment (Results, Messages, Execution Plan)", result: "Shows that panel, or hides it when it is the one showing; the tooltip says Show or Hide. A segment that can't be used is at 30% and disabled."),
                .init(trigger: "Click empty footer space", result: "Opens or closes the panel."),
                .init(trigger: "Click a pill on the right", result: "Its own popover rises above it (round 41.5): the selection's exact figures (with Settings › Results › Selection summary the pill can add the sum and/or average) with Copy and Copy All; the rows (what and how many); where the time went; the status with Cancel, Commit or Roll Back and Show in Editor. Export and copy are in the grid's right-click menu."),
                .init(trigger: "A query fails, or returns no rows", result: "A banner at the top left of the card: symbol, title, the message, SQL Server's numbers as chips, and Show in Editor, Messages, Copy Error (round 41.3). Running, No rows and Cancelled use the same banner."),
                .init(trigger: "Open Messages", result: "The counts at the top filter (\"1 error · 2 messages\"), copy and clear are in ⋯; each statement is a heading with its messages under it; errors are a red symbol and semibold text; the symbol of a server message opens what the server returned (round 41.4)."),
                .init(trigger: "Click the server · database chip", result: "A system popover rises above the chip with a filter field (prompt \"Filter N databases\") and the databases; type to narrow, ↑ ↓ and Return, or click; Esc or a click away closes it. The chip is disabled, with the name as its tooltip, when the tab can't switch database."),
                .init(trigger: "Hover a result row", result: "A faint rounded tint on the row and its row number turns accent."),
                .init(trigger: "Hover a column header", result: "The sort arrow appears at its trailing edge (it also stays while the column is sorted); clicking the arrow sorts, clicking elsewhere selects the column."),
                .init(trigger: "Select cells", result: "One rounded outline around the whole selected range, a stronger ring on the active cell, and the row numbers of the selected rows in accent."),
                .init(trigger: "Scroll rows under the footer", result: "They soften into the system's thinnest material, with a 15% tint of the card colour, fading in from clear 40pt above the footer to full at the card's edge along an exponential curve, so no row meets it at once (round 44, FooterMaterialBlur)."),
                .init(trigger: "A result cell", result: "Numbers and dates right-aligned with tabular digits, booleans as ✓ or ✗ centred, NULL as italic grey text; copying and exporting still use the raw values."),
            ],
            motions: [
                .init(name: "Results grow out of the footer", curve: "house spring", duration: "0.45s"),
                .init(name: "Results fold back", curve: "smooth, no overshoot", duration: "0.45s", note: "echoMotion.settle"),
                .init(name: "Switcher opens and closes", curve: "house spring", duration: "0.45s", note: "the popover's own presentation; the footer animates its open state"),
                .init(name: "Segment press", curve: "press curve", duration: "0.16s", note: "echoMotion.press"),
            ],
            measurements: [
                .init(label: "Footer height", value: "34pt", token: "LayoutTokens.Footer.height"),
                .init(label: "Footer padding", value: "12pt on the sides, 8pt between items", token: "SpacingTokens.sm / xs"),
                .init(label: "Chip height", value: "24pt", token: "LayoutTokens.Footer.chipHeight"),
                .init(label: "Chip padding", value: "10pt horizontal", token: "LayoutTokens.Footer.chipHorizontalPadding"),
                .init(label: "Segment pill", value: "glass capsule, 2pt padding; segments 28 × 20pt", token: "LayoutTokens.Footer.pillPadding / segmentWidth"),
                .init(label: "Active segment", value: "a card-coloured capsule with the rail disc's shadow", token: "ShadowTokens.railSelection"),
                .init(label: "Footer lift", value: "4pt above the bottom edge", token: "LayoutTokens.Footer.bottomLift"),
                .init(label: "Right-hand side", value: "A glass pill per entry, 4pt apart: the selection's count, rows, time, status", token: "FooterMetricsStyle.pillPerEntry"),
                .init(label: "Pill popovers", value: "260pt for the selection and rows, 320pt for time and status; 16pt padding", token: "LayoutTokens.FloatingSurface.smallWidth / mediumWidth"),
                .init(label: "Behind the footer", value: "the system's ultra-thin material plus the card colour at 15%, over the footer and 40pt above it, faded in as (e^(4.5t) − 1) / (e^4.5 − 1) from the top (round 44: BT4, BH3, CV6, TT1)", token: "LayoutTokens.EdgeBlur.materialReach / materialGrowth / materialTintOpacity"),
                .init(label: "Scroll bars", value: "the system's, on the footer's top edge and as wide as the footer: the thumb 9pt above the pills, 42pt above the card's edge; the vertical bar down to it", token: "LayoutTokens.Footer.scrollBarBottom"),
                .init(label: "Blur behind the bar", value: "under a footer the material already reaches past the bar (it lies over it at about 6%); no other scroll bar in Echo gets a blur (owner, after round 44)", token: "LayoutTokens.EdgeBlur.raiseDuration / settleDuration / raisedHold"),
                .init(label: "Soft side edges", value: "32pt into the card's colour where more columns wait", token: "LayoutTokens.EdgeBlur.sideFadeWidth"),
                .init(label: "Switcher card", value: "260pt wide, 12pt padding, 28pt rows, list up to 280pt", token: "LayoutTokens.FloatingSurface.smallWidth / Footer.switcherListMaxHeight"),
                .init(label: "Header", value: "36pt: name 12pt semibold over the type in 10pt monospaced; one hairline at its true bottom, drawn by the header itself", token: "ResultsGridMetrics.headerHeight"),
                .init(label: "State banner", value: "top left, 16pt padding, a title-3 symbol, 13pt semibold title over 13pt secondary detail", token: "SpacingTokens.md / TypographyTokens.title3"),
                .init(label: "Cells", value: "12pt, 10pt side padding, columns 56 to 420pt; monospaced cells are a setting", token: "ResultsGridMetrics"),
                .init(label: "Row numbers", value: "12pt monospaced digits, right-aligned, the gutter fitting the digits (at least 3) with 8pt either side; the editor's gutter style, Hairline by default", token: "ResultsGridMetrics.rowNumberFontSize / minimumRowNumberDigits"),
                .init(label: "Row hover", value: "2pt by 1pt inset, 5pt corner", token: "ResultsGridMetrics.hoverCornerRadius"),
                .init(label: "Selection", value: "accent fill 18%, 1pt outline at 65%, ring 2pt with 4pt corner on the active cell", token: "ResultsGridMetrics.activeCellRingWidth"),
            ],
            rules: [
                .init(text: "A glass pill per entry on the right",
                      why: "Status, selection summary, rows and time each sit in a pill the size of the chip. One big pill and plain text were rejected.",
                      rounds: ["decided.round10-footer-and-switcher"]),
                .init(text: "Soft blur behind the footer (FB1)",
                      why: "A hard edge left a solid band behind the footer; a glass bar with glass pills inside would be glass on glass.",
                      rounds: ["decided.round9-footer-scroller-tabs"]),
                .init(text: "The scroll bars sit on the footer's top edge (round 27, E)",
                      why: "As far above the pills as the pills sit above the edge, so the bar is part of the footer without touching it. Above the footer (Echo before), along the bottom edge, inside the footer, a lane of its own, a glass track and a position chip were not chosen.",
                      rounds: ["ongoing.results-scrollers-r27"]),
                .init(text: "The bar is as wide as the footer, and the blur rises past it while it shows (round 27, L2 and U5)",
                      why: "Bar and footer read as one block on the same soft ground. The grid's width, sharp rows behind the bar, a blur always that high, a glass lane and a band of the card's colour were not chosen; the owner then asked for the same blur behind every horizontal bar in Echo.",
                      rounds: ["ongoing.results-scrollers-r27"]),
                .init(text: "The footer is lifted 4pt (FP1)",
                      why: "It reads as floating on the card rather than fixed to its edge.",
                      rounds: ["decided.round9-footer-scroller-tabs"]),
                .init(text: "The switcher is a card above the chip",
                      why: "The chip stays visible. A native menu and picking the database in the tree were rejected. It is a system popover so the glass matches.",
                      rounds: ["decided.round10-footer-and-switcher"]),
                .init(text: "The results grow up out of the footer",
                      why: "It should look as if the footer itself expands. Splitting the editor in place and a crossfade were rejected.",
                      rounds: ["decided.round10-footer-and-switcher"]),
                .init(text: "The row numbers follow the editor's gutter style (round 47, SS0, GS2)",
                      why: "One setting keeps the two gutters alike; Hairline became the default for both. The edge starts below the header so the corner and first name have no vertical line. The gutter fits the digits (GW1), names stay left, the # selects all (GC2), selected rows' numbers sit on the selection's tint (SR1), and shaded rows stop at the gutter (RS1). Right-aligning the names with their data (HA1) and the lane's centred numbers were not taken.",
                      rounds: ["ongoing.results-gutter-r47"]),
                .init(text: "One line under the column header, at its true bottom (round 41.1, HL1)",
                      why: "Echo drew a second full-width line 4pt from the system's, and the system's scroll pocket stops 4pt short of the 36pt header, so rows showed in the gap. The header now paints its full height and draws the one line. The column dividers stay: they show where to drag a width (VD0).",
                      rounds: ["ongoing.results-header-lines-r41"]),
                .init(text: "The selection pill is the count, plus the sum and/or average if Settings says so; every figure is in its popover (round 41.2)",
                      why: "The full sum and average pushed the other pills aside and couldn't be copied. The owner chose the count (SP3) over a compact sum; the popover lists every figure, exact, each copyable (PO1, FG1, TX0).",
                      rounds: ["ongoing.results-selection-summary-r41"]),
                .init(text: "Each pill opens its own popover with its actions (round 41.5, PP2)",
                      why: "One shared statistics popover answered none of them. Rows, time and status each say what they are about and offer what goes with it (PR0, PT0, PS0).",
                      rounds: ["ongoing.results-pill-popovers-r41"]),
                .init(text: "States are a banner at the top of the card (round 41.3, EP1)",
                      why: "A card is read from the top left; a centred poster left a long grey line on wide windows. The editor keeps its red pill (HL0); SQL Server's numbers are quiet chips (ED0); Copy Error joins the actions (EA1).",
                      rounds: ["ongoing.results-error-page-r41"]),
                .init(text: "Messages are grouped by statement, with no strip (round 41.4)",
                      why: "Which statement said what is what Messages is for (ML1). Category and delta columns, pink rows, Echo's own lines and the metrics row were distractions (EE1, EM0, DM1); counts that filter replace the segmented control and its overlapping trash (MT1).",
                      rounds: ["ongoing.results-messages-r41"]),
                .init(text: "Selection is one outline around the range",
                      why: "Per-row outlines showed seams.",
                      rounds: ["decided.results-grid"]),
            ],
            code: [
                "Echo/Sources/Shared/DesignSystem/Components/BottomPanelStatusBar.swift",
                "Echo/Sources/Shared/DesignSystem/Components/DatabaseSwitcherCard.swift",
                "Echo/Sources/Shared/DesignSystem/Components/BackdropEdgeBlur.swift",
                "Echo/Sources/Shared/DesignSystem/Components/FooterScrollOverlay.swift",
                "Echo/Sources/Shared/DesignSystem/Components/ScrollBarBlur.swift",
                "Echo/Sources/Shared/DesignSystem/Components/ScrollSideFades.swift",
                "Echo/Sources/Shared/DesignSystem/Components/ContentPanelCards.swift",
                "Echo/Sources/Features/QueryWorkspace/Views/Results/NativeTable/",
                "Echo/Sources/Features/QueryWorkspace/Views/Results/Section/",
                "Echo/Sources/Features/QueryWorkspace/Views/Results/ExecutionConsole/",
            ]
        ) {
            FooterResultsSpecimen()
        },
        spec: FooterResultsSpec.spec(stageHeight: 480) { FooterResultsSpecimen() }
    )
}

private struct FooterResultsSpecimen: View {
    @State private var segment: PanelSegment = .results

    private var footerZone: CGFloat { LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift }

    var body: some View {
        ZStack(alignment: .bottom) {
            LabAppKitGrid(
                isDrifting: false, bottomInset: footerZone,
                blurHeight: footerZone + LayoutTokens.EdgeBlur.fade, blurRadii: LayoutTokens.EdgeBlur.radii)
                .specAnchor("4.1")
            BottomPanelStatusBar(configuration: configuration)
                .padding(.bottom, LayoutTokens.Footer.bottomLift)
                .specAnchor("2.1")
        }
        .workspaceCard()
        .specAnchor("1.1")
        .frame(maxWidth: 760)
        .padding(SpacingTokens.lg)
    }

    private var configuration: BottomPanelStatusBarConfiguration {
        var configuration = BottomPanelStatusBarConfiguration(
            serverName: "dwh", databaseName: "Dev_DM_Reporting",
            availableSegments: [.results, .messages, .executionPlan],
            selectedSegment: segment, onSelectSegment: { segment = $0 },
            onTogglePanel: {}, isPanelOpen: true)
        configuration.metrics = .init(rowCountText: "96", rowCountLabel: "rows", durationText: "38 ms", selectionText: "3 cells")
        configuration.statusBubble = .init(label: "Ready", tint: .green, isPulsing: false)
        configuration.availableDatabases = ["Dev_DM_Reporting", "Dev_DW_Reporting", "DM_Prod"]
        configuration.metricsStyle = .pillPerEntry
        return configuration
    }
}

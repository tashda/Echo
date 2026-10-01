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
                level: .code, commit: "0eb8696c", date: "2026-10-01",
                note: "Read from BottomPanelStatusBar (+Metrics), DatabaseSwitcherCard, BackdropEdgeBlur, ContentPanelCards, ResultsGridMetrics, ResultTableRowView, ResultTableHeaderCell, ResultCellPresentation and the Footer and EdgeBlur tokens. The specimen uses Echo's real BottomPanelStatusBar over a sample grid."),
            stageHeight: 480,
            behaviours: [
                .init(trigger: "Run a query", result: "The results grow up out of the footer: the editor card grows back to full height while the results card lands on its bottom edge."),
                .init(trigger: "Close the results", result: "They fold back into the footer smoothly, the card's chrome fading out."),
                .init(trigger: "Click a segment (Results, Messages, Execution Plan)", result: "Shows that panel, or hides it when it is the one showing; the tooltip says Show or Hide. A segment that can't be used is at 30% and disabled."),
                .init(trigger: "Click empty footer space", result: "Opens or closes the panel. Clicking the metrics does the same, unless the tab has a statistics popover, which it toggles instead."),
                .init(trigger: "Click the server · database chip", result: "A system popover rises above the chip with a filter field (prompt \"Filter N databases\") and the databases; type to narrow, ↑ ↓ and Return, or click; hovering highlights a row but never scrolls the list (only the wheel, the keys and filtering do); Esc or a click away closes it. The chip is disabled, with the name as its tooltip, when the tab can't switch database."),
                .init(trigger: "Hover a result row", result: "A faint rounded tint on the row and its row number turns accent."),
                .init(trigger: "Hover a column header", result: "The sort arrow appears at its trailing edge (it also stays while the column is sorted); clicking the arrow sorts, clicking elsewhere selects the column."),
                .init(trigger: "Select cells", result: "One rounded outline around the whole selected range, a stronger ring on the active cell, and the row numbers of the selected rows in accent."),
                .init(trigger: "Scroll rows under the footer", result: "They blur away softly (BackdropEdgeBlur) under a light tint of the card colour that grows towards the bottom; no bar, no solid band."),
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
                .init(label: "Right-hand side", value: "A glass pill per entry, 4pt apart: selection summary, rows, time, status", token: "FooterMetricsStyle.pillPerEntry"),
                .init(label: "Behind the footer", value: "Soft blur radii 0.75 · 1.5 · 3 · 5 · 7.5 · 10pt over 24pt beyond the footer, each step fading along an S curve, and a card tint at 35%", token: "LayoutTokens.EdgeBlur"),
                .init(label: "Scroll bars", value: "the system's, on the footer's top edge and as wide as the footer: the thumb 9pt above the pills, 42pt above the card's edge; the vertical bar down to it", token: "LayoutTokens.Footer.scrollBarBottom"),
                .init(label: "Blur behind the bar", value: "rises past the bar in 0.32s while it shows, settles in 0.5s 0.9s after the last scroll; every horizontal bar in Echo", token: "LayoutTokens.EdgeBlur.raiseDuration / settleDuration / raisedHold"),
                .init(label: "Soft side edges", value: "32pt into the card's colour where more columns wait", token: "LayoutTokens.EdgeBlur.sideFadeWidth"),
                .init(label: "Switcher card", value: "260pt wide, 12pt padding, 28pt rows, list up to 280pt", token: "LayoutTokens.FloatingSurface.smallWidth / Footer.switcherListMaxHeight"),
                .init(label: "Header", value: "36pt: name 12pt semibold over the type in 10pt monospaced", token: "ResultsGridMetrics.headerHeight"),
                .init(label: "Cells", value: "12pt, 10pt side padding, columns 56 to 420pt; monospaced cells are a setting", token: "ResultsGridMetrics"),
                .init(label: "Row numbers", value: "12pt monospaced digits, at least 6 digits wide", token: "ResultsGridMetrics.rowNumberFontSize / minimumRowNumberDigits"),
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
        configuration.metrics = .init(rowCountText: "96", rowCountLabel: "rows", durationText: "38 ms", selectionText: "3 cells · Sum 263,487")
        configuration.statusBubble = .init(label: "Ready", tint: .green, isPulsing: false)
        configuration.availableDatabases = ["Dev_DM_Reporting", "Dev_DW_Reporting", "DM_Prod"]
        configuration.metricsStyle = .pillPerEntry
        return configuration
    }
}

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
                level: .code, commit: "a24192df", date: "2026-09-30",
                note: "The specimen uses Echo's real BottomPanelStatusBar over a grid; the log is the source for the rest."),
            stageHeight: 480,
            behaviours: [
                .init(trigger: "Run a query", result: "The results grow up out of the footer: the editor card grows back to full height while the results card lands on its bottom edge."),
                .init(trigger: "Close the results", result: "They fold back into the footer smoothly, the card's chrome fading out."),
                .init(trigger: "Click the server · database chip", result: "A card rises above the chip with a filter field and the databases; Esc or a click away closes it. It is a system popover."),
                .init(trigger: "Hover a result row or header", result: "A tint on the row; the header shows the column type on a second line."),
                .init(trigger: "Select cells", result: "One rounded outline around the whole selected range and a stronger ring on the active cell."),
                .init(trigger: "Scroll rows under the footer", result: "They blur away softly (BackdropEdgeBlur); no bar, no solid band."),
            ],
            motions: [
                .init(name: "Results grow out of the footer", curve: "house spring", duration: "0.45s"),
                .init(name: "Results fold back", curve: "smooth, no overshoot", duration: "0.45s", note: "echoMotion.settle"),
                .init(name: "Switcher card rises", curve: "house spring, with a small rise and fade", duration: "0.45s"),
            ],
            measurements: [
                .init(label: "Footer height", value: "34pt", token: "LayoutTokens.Footer.height"),
                .init(label: "Chip height", value: "24pt", token: "LayoutTokens.Footer.chipHeight"),
                .init(label: "Chip padding", value: "10pt horizontal", token: "LayoutTokens.Footer.chipHorizontalPadding"),
                .init(label: "Segment width", value: "28pt", token: "LayoutTokens.Footer.segmentWidth"),
                .init(label: "Footer lift", value: "4pt above the bottom edge", token: "LayoutTokens.Footer.bottomLift"),
                .init(label: "Right-hand side", value: "A glass pill per entry", token: "FooterMetricsStyle.pillPerEntry"),
                .init(label: "Behind the footer", value: "Soft blur", token: "BackdropEdgeBlur, LayoutTokens.EdgeBlur"),
                .init(label: "Results cells", value: "Proportional; monospaced is a setting"),
            ],
            rules: [
                .init(text: "A glass pill per entry on the right",
                      why: "Status, selection summary, rows and time each sit in a pill the size of the chip. One big pill and plain text were rejected.",
                      rounds: ["decided.round10-footer-and-switcher"]),
                .init(text: "Soft blur behind the footer (FB1)",
                      why: "A hard edge left a solid band behind the footer; a glass bar with glass pills inside would be glass on glass.",
                      rounds: ["decided.round9-footer-scroller-tabs"]),
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
                "Echo/Sources/Shared/DesignSystem/Components/ContentPanelCards.swift",
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

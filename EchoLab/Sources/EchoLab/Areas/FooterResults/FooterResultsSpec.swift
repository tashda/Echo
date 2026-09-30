import SwiftUI

/// The footer and results by piece, each with a stable ID (`FTR-2.4`). Values come from
/// `LayoutTokens.Footer`, `LayoutTokens.EdgeBlur`, `BottomPanelStatusBar` and the results grid.
@MainActor
enum FooterResultsSpec {
    private static let bar = "Echo/Sources/Shared/DesignSystem/Components/BottomPanelStatusBar.swift"
    private static let switcher = "Echo/Sources/Shared/DesignSystem/Components/DatabaseSwitcherCard.swift"
    private static let blur = "Echo/Sources/Shared/DesignSystem/Components/BackdropEdgeBlur.swift"
    private static let panels = "Echo/Sources/Shared/DesignSystem/Components/ContentPanelCards.swift"
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
                .layout(.row("Height", "34pt", token: "LayoutTokens.Footer.height"), .row("Lift", "4pt above the bottom edge", token: "LayoutTokens.Footer.bottomLift")),
                .material(.row("Background", "none: no bar and no solid band")),
            ], rounds: [r9], files: [bar]),
            SpecElement(number: "2.2", name: "Soft blur behind", summary: "Rows scroll under the footer and blur away softly (FB1).", groups: [
                .material(.row("Blur radii", "1 · 3 · 6 · 10pt, from the sharp content to the edge", token: "LayoutTokens.EdgeBlur.radii"),
                          .row("Fades beyond the footer", "16pt", token: "LayoutTokens.EdgeBlur.fade"),
                          .row("Step overlap", "30%", token: "LayoutTokens.EdgeBlur.step"),
                          .row("Card tint over the blur", "35%", token: "LayoutTokens.EdgeBlur.tintOpacity")),
                .behaviour(.row("Why", "a hard edge left a solid band; a glass bar with glass pills inside would be glass on glass")),
            ], rounds: [r9], files: [blur]),
            SpecElement(number: "2.3", name: "Segments", summary: "Results, Messages and Execution Plan, at the left.", groups: [
                .layout(.row("Segment width", "28pt", token: "LayoutTokens.Footer.segmentWidth")),
                .behaviour(.row("Click", "switches what the panel shows")),
            ], files: [bar]),
            SpecElement(number: "2.4", name: "Server and database chip", summary: "Shows where the tab runs; click to switch database.", groups: [
                .material(.row("Glass", "Liquid Glass capsule")),
                .layout(.row("Height", "24pt", token: "LayoutTokens.Footer.chipHeight"), .row("Horizontal padding", "10pt", token: "LayoutTokens.Footer.chipHorizontalPadding")),
            ], rounds: [r10], files: [bar]),
            SpecElement(number: "2.5", name: "Metric pills", summary: "A glass pill per entry at the right: status, selection summary, rows and time.", groups: [
                .material(.row("Glass", "one Liquid Glass pill per entry"), .row("Size", "the chip's height", token: "LayoutTokens.Footer.chipHeight"),
                          .row("Pill padding", "2pt", token: "LayoutTokens.Footer.pillPadding")),
                .behaviour(.row("Why one each", "one big pill and plain text were rejected"), .row("Style", "pill per entry", token: "FooterMetricsStyle.pillPerEntry")),
            ], rounds: [r10], files: [bar]),
            SpecElement(number: "2.6", name: "Status", summary: "A dot and a word: Ready, Running, Error.", groups: [
                .type(.row("Font", "detail 11pt", token: "TypographyTokens.detail")),
                .states(.row("Ready", "green dot"), .row("Running", "the dot pulses while a query runs")),
            ], files: [bar]),
        ]),
        SpecPart(number: "3", name: "Database switcher", summary: "The card that rises above the chip.", elements: [
            SpecElement(number: "3.1", name: "Card", summary: "A filter field and the databases, above the chip so the chip stays visible.", groups: [
                .material(.row("Kind", "a system popover, so the glass matches")),
                .layout(.row("Tallest list", "280pt, then it scrolls", token: "LayoutTokens.Footer.switcherListMaxHeight")),
                .motion(.row("Rise", "house spring with a small rise and fade, 0.45s")),
                .behaviour(.row("Close", "Esc or a click away"), .row("Rejected", "a native menu, and picking the database in the tree")),
            ], rounds: [r10], files: [switcher]),
        ]),
        SpecPart(number: "4", name: "Results grid", summary: "The table of results.", elements: [
            SpecElement(number: "4.1", name: "Cells", summary: "Proportional text; monospaced is a setting.", groups: [
                .type(.row("Default", "proportional"), .row("Monospaced", "a setting")),
            ], rounds: ["decided.results-grid"]),
            SpecElement(number: "4.2", name: "Column header", summary: "The column's name, and its type on a second line on hover.", groups: [
                .states(.row("Hover", "a tint on the header; the type shows on a second line")),
            ], rounds: ["decided.results-grid"]),
            SpecElement(number: "4.3", name: "Row hover", summary: "A tint on the row under the pointer.", groups: [
                .states(.row("Hover", "a tint on the row")),
            ], rounds: ["decided.results-grid"]),
            SpecElement(number: "4.4", name: "Selection", summary: "One rounded outline around the selected range and a stronger ring on the active cell.", groups: [
                .material(.row("Range", "one outline around the whole range"), .row("Active cell", "a stronger ring")),
                .behaviour(.row("Why", "per-row outlines showed seams")),
            ], rounds: ["decided.results-grid"]),
        ]),
    ]
}

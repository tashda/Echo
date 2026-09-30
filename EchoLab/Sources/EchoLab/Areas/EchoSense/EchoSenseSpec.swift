import SwiftUI

/// The completion popup by piece, each with a stable ID (`SNS-2.1`). Ranking and rules are in
/// EchoSense's AUTOCOMPLETE_SPEC.md and can be tried under Test.
@MainActor
enum EchoSenseSpec {
    private static let tokens = "Packages/EchoDesignSystem/.../LayoutToken+EchoSense.swift"
    private static let editor = "Echo/Sources/Features/QueryWorkspace/Views/Query/SQLTextView/"
    private static let r14 = "ported.Round 14 · EchoSense selection"

    static func spec<Specimen: View>(stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen) -> AreaSpec {
        AreaSpec(code: "SNS", stageHeight: stageHeight, parts: parts, specimen: specimen)
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Popup", summary: "A card of suggestions under the caret.", elements: [
            SpecElement(number: "1.1", name: "Card", summary: "The popup looks like the other cards (ESR5).", groups: [
                .material(.row("Fill", "the text background", token: "ColorTokens.EchoSense.background", swatch: ColorTokens.EchoSense.background),
                          .row("Edge", "separator", token: "ColorTokens.EchoSense.edge")),
                .layout(.row("Width", "300 to 480pt", token: "LayoutTokens.EchoSense.minWidth / maxWidth"),
                        .row("Corner", "follows Card Corners, capped at 14pt (floor 8)", token: "LayoutTokens.EchoSense.cornerRadius(cardCornerRadius:)"),
                        .row("Padding", "4pt", token: "LayoutTokens.EchoSense.padding"),
                        .row("Gap to the caret's line", "4pt", token: "LayoutTokens.EchoSense.caretGap")),
            ], rounds: [r14], files: [tokens]),
            SpecElement(number: "1.2", name: "Visible rows", summary: "Eight rows, then it scrolls.", groups: [
                .layout(.row("Rows", "8", token: "LayoutTokens.EchoSense.visibleRows")),
            ], files: [tokens]),
        ]),
        SpecPart(number: "2", name: "Row", summary: "One suggestion.", elements: [
            SpecElement(number: "2.1", name: "Row", summary: "A badge, the name, the alias and the type (ES1).", groups: [
                .layout(.row("Height", "24pt", token: "LayoutTokens.EchoSense.rowHeight"), .row("Spacing", "8pt", token: "rowSpacing"),
                        .row("Horizontal padding", "8pt", token: "rowHorizontalPadding"),
                        .row("Corner", "the popup's minus its padding", token: "LayoutTokens.EchoSense.rowCornerRadius(cardCornerRadius:)")),
            ], rounds: [r14], files: [tokens]),
            SpecElement(number: "2.2", name: "Kind badge", summary: "A small tile telling what the suggestion is.", groups: [
                .layout(.row("Size", "16pt", token: "LayoutTokens.EchoSense.badgeSize"), .row("Corner", "4pt", token: "badgeCornerRadius")),
                .material(.row("Fill", "the kind's colour at 16%", token: "ColorTokens.EchoSense.badgeFillOpacity")),
            ], files: [tokens]),
            SpecElement(number: "2.3", name: "Name", summary: "In the editor's font; the letters you typed are bold in the accent colour.", groups: [
                .type(.row("Font", "the editor font"), .row("Match", "bold accent", token: "ColorTokens.EchoSense.match")),
            ], rounds: [r14], files: [editor]),
            SpecElement(number: "2.4", name: "Same-named columns", summary: "Always show their alias or table.", groups: [
                .behaviour(.row("Rule", "an ambiguous column is never shown without saying which table it is from")),
            ], files: [editor]),
        ]),
        SpecPart(number: "3", name: "Selection", summary: "Which row Return will insert.", elements: [
            SpecElement(number: "3.1", name: "Typing", summary: "The selected row is tinted while you type.", groups: [
                .material(.row("Fill", "accent at 16%", token: "ColorTokens.EchoSense.typingSelection")),
            ], rounds: [r14], files: [tokens]),
            SpecElement(number: "3.2", name: "Choosing", summary: "After ↑ or ↓ the row turns solid: Return inserts it (ESR4).", groups: [
                .material(.row("Fill", "solid accent", token: "ColorTokens.EchoSense.choosingSelection"),
                          .row("Text", "reversed", token: "ColorTokens.EchoSense.choosingText")),
                .motion(.row("Change", "instant, on the first arrow key")),
            ], rounds: [r14], files: [tokens]),
        ]),
        SpecPart(number: "4", name: "Footer", summary: "What the selected row is.", elements: [
            SpecElement(number: "4.1", name: "Detail footer", summary: "An inset rounded footer explaining the selected row (ES4).", groups: [
                .material(.row("Fill", "primary at 3.5%", token: "ColorTokens.EchoSense.footer")),
                .layout(.row("Padding", "8pt", token: "footerPadding"), .row("Line spacing", "2pt", token: "footerLineSpacing"),
                        .row("Concentric", "with the popup's corner")),
                .behaviour(.row("Rejected", "a side panel and a one-second delay")),
            ], rounds: [r14], files: [tokens]),
        ]),
        SpecPart(number: "5", name: "Behaviour", summary: "How it is triggered and dismissed.", elements: [
            SpecElement(number: "5.1", name: "Trigger", summary: "Typing, or ⌘. by hand (it can be rebound).", groups: [.behaviour(.row("Type", "suggestions appear"), .row("⌘.", "triggers by hand"))], files: [editor]),
            SpecElement(number: "5.2", name: "Dismiss", summary: "Esc closes the popup.", groups: [.behaviour(.row("Esc", "dismisses"))], files: [editor]),
            SpecElement(number: "5.3", name: "Ghost text", summary: "A setting, off by default (ES3).", groups: [
                .behaviour(.row("On", "the top match shows inline in grey; Tab accepts it")),
            ], rounds: [r14], files: [editor]),
        ]),
    ]
}

import SwiftUI

/// The completion popup by piece, each with a stable ID (`SNS-2.1`). Ranking and rules are in
/// EchoSense's AUTOCOMPLETE_SPEC.md and can be tried under Test.
@MainActor
enum EchoSenseSpec {
    private static let tokens = "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/LayoutToken+EchoSense.swift"
    private static let list = "Echo/Sources/Features/QueryWorkspace/Views/Query/Autocomplete/"
    private static let editor = "Echo/Sources/Features/QueryWorkspace/Views/Query/SQLTextView/Completion/"
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
                .behaviour(.row("Window", "a borderless panel that never takes focus; the system draws the shadow", token: "SQLCompletionPanel"),
                           .row("Width", "as wide as the longest name plus its badge, chip and type, within 300 to 480pt")),
            ], rounds: [r14], files: [tokens, list + "AutoCompletionListView.swift", list + "SQLCompletionPanel.swift"]),
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
            SpecElement(number: "2.4", name: "Qualifier chip", summary: "The alias or table, after the name, so same-named columns are never ambiguous.", groups: [
                .type(.row("Font", "11pt medium", token: "TypographyTokens.detail")),
                .material(.row("Fill", "primary at 7%", token: "ColorTokens.EchoSense.chip"), .row("Corner", "4pt", token: "badgeCornerRadius")),
                .layout(.row("Padding", "5pt horizontal", token: "LayoutTokens.EchoSense.chipHorizontalPadding")),
            ], files: [list + "AutoCompletionRowView.swift"]),
            SpecElement(number: "2.5", name: "Trailing text", summary: "The type or schema at the right.", groups: [
                .type(.row("Font", "11pt tertiary", token: "TypographyTokens.detail"), .row("Lines", "1")),
            ], files: [list + "AutoCompletionRowView.swift"]),
            SpecElement(number: "2.6", name: "Fuzzy matches", summary: "Typed letters in a name that isn't a plain prefix.", groups: [
                .behaviour(.row("Highlight", "the first place the text appears; otherwise each typed letter in order")),
            ], files: [list + "AutoCompletionRowView.swift"]),
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
                .type(.row("Name", "the editor font, semibold"), .row("Kind or type", "11pt secondary: a column's data type, otherwise its kind"),
                      .row("Detail", "11pt secondary, up to 2 lines"), .row("Keys", "↩ Insert · ⇥ Complete · ↑↓ Choose · ⎋ Close, label size, tertiary, 12pt apart", token: "keyHintSpacing")),
                .behaviour(.row("Timing", "straight away for the selected row, no delay"), .row("Rejected", "a side panel and a one-second delay")),
            ], rounds: [r14], files: [tokens, list + "AutoCompletionDetailFooter.swift"]),
            SpecElement(number: "4.2", name: "Status message", summary: "Above the rows, when EchoSense has something to say.", groups: [
                .type(.row("Font", "11pt medium, secondary", token: "TypographyTokens.detail")),
            ], files: [list + "AutoCompletionListView.swift"]),
        ]),
        SpecPart(number: "5", name: "Behaviour", summary: "How it is triggered and dismissed.", elements: [
            SpecElement(number: "5.1", name: "Trigger", summary: "Typing, or ⌘. by hand (it can be rebound).", groups: [.behaviour(.row("Type", "suggestions appear"), .row("⌘.", "Show EchoSense Suggestions, in the Query menu"))], files: [editor, "Echo/Sources/Features/AppHost/EchoApp+QueryMenu.swift"]),
            SpecElement(number: "5.2", name: "Keys", summary: "The editor forwards them; the popup never takes focus.", groups: [
                .behaviour(.row("↑ ↓", "move the selection, wrapping round; the row turns solid"), .row("Return or Tab", "inserts the selected suggestion"),
                           .row("Shift-Tab", "moves the selection up"), .row("Esc", "dismisses")),
            ], files: [list + "SQLAutoCompletionController.swift"]),
            SpecElement(number: "5.3", name: "Ghost text", summary: "A setting, off by default: Ghost text instead of the list (ES3).", groups: [
                .behaviour(.row("On", "while typing, the top match shows inline in grey instead of the list; Tab accepts it")),
            ], rounds: [r14], files: [editor + "SQLTextView+GhostText.swift", "Echo/Sources/Features/Preferences/Views/EchoSenseSettings/EchoSenseSettingsView.swift"]),
        ]),
    ]
}

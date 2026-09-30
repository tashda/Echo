import SwiftUI

/// The completion popup as it is in Echo today (plan Phase 12, decisions 2026-09-30). Ranking
/// and rules are in EchoSense's AUTOCOMPLETE_SPEC.md and can be tried under Test.
@MainActor
enum EchoSenseArea {
    static let area = LabArea(
        id: "echosense",
        title: "EchoSense",
        symbol: "text.badge.star",
        summary: "A card of rows with a kind badge, the name in the editor's font with your letters highlighted, and a footer that explains the selected row.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "ea0ee95b", date: "2026-09-30",
                note: "Read from AutoCompletionListView, AutoCompletionRowView, AutoCompletionDetailFooter, SQLCompletionPanel, SQLAutoCompletionController, the EchoSense tokens and the Query menu. The specimen is Round 14's popup in a small editor; ghost text is a setting and is not drawn here."),
            stageHeight: 380,
            behaviours: [
                .init(trigger: "Type", result: "Suggestions appear under the caret; the selected row is tinted. The popup never takes focus: typing stays in the editor."),
                .init(trigger: "Press ↑ or ↓", result: "The selection moves (wrapping round) and turns solid, meaning Return inserts it."),
                .init(trigger: "Press Return or Tab", result: "Inserts the selected suggestion. Shift-Tab moves the selection up. What gets replaced, the quoting of names that need it and the space after a keyword come from EchoSense's SQLEditorAcceptance, the same code the scenarios run."),
                .init(trigger: "Type a space", result: "Opens the popup only after FROM, JOIN, UPDATE, CALL, EXEC, EXECUTE or INTO (EchoSense's SQLEditorTriggerPolicy). The spec also wants clause keywords and commas to open it; Test › Scenarios lists those as known issues."),
                .init(trigger: "⌘.", result: "Triggers EchoSense by hand (Show EchoSense Suggestions in the Query menu; it can be rebound)."),
                .init(trigger: "Same-named columns", result: "Show their qualifier (alias or table) as a chip after the name, so they are never ambiguous."),
                .init(trigger: "Typed letters", result: "In each name the typed letters are bold in the accent colour: the first place the text appears, or, for a fuzzy match, each letter in order."),
                .init(trigger: "The selected row", result: "The footer describes it straight away, with no timer: its name and type, where it comes from, then the keys ↩ Insert, ⇥ Complete, ↑↓ Choose, ⎋ Close."),
                .init(trigger: "A status message", result: "Shown above the rows in secondary medium type when EchoSense has one."),
                .init(trigger: "Ghost text (setting: Ghost text instead of the list, off)", result: "While typing, the top match shows inline in grey instead of the list; Tab accepts it."),
                .init(trigger: "Esc", result: "Dismisses the popup."),
            ],
            motions: [
                .init(name: "Tint to solid", curve: "fill change", duration: "instant", note: "on the first arrow key"),
            ],
            measurements: [
                .init(label: "Row height", value: "24pt", token: "LayoutTokens.EchoSense.rowHeight"),
                .init(label: "Visible rows", value: "8", token: "LayoutTokens.EchoSense.visibleRows"),
                .init(label: "Popup width", value: "300 to 480pt", token: "LayoutTokens.EchoSense.minWidth / maxWidth"),
                .init(label: "Popup corner", value: "follows Card Corners, capped at 14pt", token: "LayoutTokens.EchoSense.maxCornerRadius"),
                .init(label: "Row corner", value: "the popup's minus its padding", token: "LayoutTokens.EchoSense.rowCornerRadius(cardCornerRadius:)"),
                .init(label: "Kind badge", value: "16pt", token: "LayoutTokens.EchoSense.badgeSize"),
                .init(label: "Selection (typing)", value: "accent at 16%", token: "ColorTokens.EchoSense.typingSelection"),
                .init(label: "Selection (choosing)", value: "solid accent, reversed text", token: "choosingSelection / choosingText"),
                .init(label: "Row spacing", value: "8pt between badge, name, chip and type; 8pt row padding", token: "LayoutTokens.EchoSense.rowSpacing / rowHorizontalPadding"),
                .init(label: "Popup padding", value: "4pt", token: "LayoutTokens.EchoSense.padding"),
                .init(label: "Qualifier chip", value: "11pt medium on primary 7%, 4pt corner", token: "ColorTokens.EchoSense.chip"),
                .init(label: "Badge letter", value: "bold label size, on its kind colour at 16%", token: "TypographyTokens.label / badgeFillOpacity"),
                .init(label: "Footer", value: "8pt padding, 2pt line spacing, primary 3.5% fill, keys 12pt apart", token: "footerPadding / footerLineSpacing / keyHintSpacing"),
                .init(label: "Window", value: "borderless panel that never takes focus; the system draws the shadow", token: "SQLCompletionPanel"),
            ],
            rules: [
                .init(text: "Rows show a badge, the name with typed letters in bold accent, the alias, and the type",
                      why: "ES1. The name uses the editor font so it reads like the code being written.",
                      rounds: ["ported.Round 14 · EchoSense selection"]),
                .init(text: "Tinted while typing, solid once you move with the arrows",
                      why: "ESR4: the solid state tells you Return inserts it.",
                      rounds: ["ported.Round 14 · EchoSense selection"]),
                .init(text: "Details in an inset rounded footer",
                      why: "ES4: no side panel and no one-second delay; the footer is concentric with the popup.",
                      rounds: ["ported.Round 14 · EchoSense selection"]),
                .init(text: "Card material, corners follow Card Corners",
                      why: "ESR5: the popup looks like the other cards; the cap keeps the rows concentric.",
                      rounds: ["ported.Round 14 · EchoSense selection"]),
                .init(text: "Ghost text is a setting, off by default",
                      why: "ES3 was accepted only as an option."),
            ],
            code: [
                "Echo/Sources/Features/QueryWorkspace/Views/Query/Autocomplete/",
                "Echo/Sources/Features/QueryWorkspace/Views/Query/SQLTextView/Completion/",
                "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/LayoutToken+EchoSense.swift",
                "/Users/k/Development/EchoSense/AUTOCOMPLETE_SPEC.md (the EchoSense package)",
                "/Users/k/Development/EchoSense/Sources/EchoSense/SQLEditorTriggerPolicy.swift (when typing opens the popup)",
                "/Users/k/Development/EchoSense/Sources/EchoSense/SQLEditorAcceptance.swift (what accepting a suggestion inserts)",
                "/Users/k/Development/EchoSense/Sources/EchoSenseScenarios/Scenarios/ (the expected behaviour, one JSON file per group)",
            ]
        ) {
            LabRound14SenseEditor(selection: .tintThenSolid, corners: .followCards)
        },
        spec: EchoSenseSpec.spec(stageHeight: 380) { LabRound14SenseEditor(selection: .tintThenSolid, corners: .followCards) }
    )
}

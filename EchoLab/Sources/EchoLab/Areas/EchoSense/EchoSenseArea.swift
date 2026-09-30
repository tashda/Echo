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
                level: .code, commit: "a24192df", date: "2026-09-30",
                note: "Written from the decision log; the specimen is Round 14's popup in a small editor. Ghost text is a setting and is not drawn here."),
            stageHeight: 380,
            behaviours: [
                .init(trigger: "Type", result: "Suggestions appear; the selected row is tinted."),
                .init(trigger: "Press ↑ or ↓", result: "The selection turns solid, meaning Return inserts it."),
                .init(trigger: "⌘.", result: "Triggers EchoSense by hand (it can be rebound)."),
                .init(trigger: "Same-named columns", result: "Always show their alias or table, so they are never ambiguous."),
                .init(trigger: "Ghost text (setting, off)", result: "The top match shows inline in grey; Tab accepts it."),
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
                "Echo/Sources/Features/QueryWorkspace/Views/Query/SQLTextView/",
                "Packages/EchoDesignSystem/.../LayoutToken+EchoSense.swift",
                "EchoSense/AUTOCOMPLETE_SPEC.md",
            ]
        ) {
            LabRound14SenseEditor(selection: .tintThenSolid, corners: .followCards)
        }
    )
}

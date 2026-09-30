import SwiftUI

extension LabDecision {
    /// Round 10 · footer and database switcher. The specimen is the round's playground as it was when decided.
    static let round10 = LabDecision(
        id: "round10-footer-and-switcher",
        area: "Window and footer",
        title: "Round 10 · footer and database switcher",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "How should the footer's right-hand side look, and how should the database switcher open?",
        reasoning: "A glass pill per entry (status, selection summary, rows, time), the same size as the server · database chip, so FooterMetricsStyle.pillPerEntry is the default. The database switcher is L2, a card floating above the chip, which stays visible with no chip label in the card; it opens with A2, rising a little while fading in on the house spring. Also decided with this round: the results grow up out of the footer (RS2, rejecting a split in place and a crossfade); the pinned path header is removed (P1); the inspector becomes a column of cards on the canvas (IN1). The switcher later became a system popover (2026-09-29).",
        shipped: ["FooterMetricsStyle.pillPerEntry", "DatabaseSwitcherCard", "house spring"],
        supersededBy: nil,
        options: [
            LabDecisionOption(
                name: "Pill per entry, L2 card, A2 rise",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabRound10.swift", "LabRound10Switcher.swift"]
            ) {
                LabRound10Playground()
            }
        ]
    )
}

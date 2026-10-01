import SwiftUI

extension LabDecision {
    /// Round 13 · new tab bar directions. The specimen is the round's playground as it was when decided.
    static let round13 = LabDecision(
        id: "round13-tab-directions",
        area: "Tabs",
        title: "Round 13 · new tab bar directions",
        symbol: "xmark.circle",
        decidedOn: "2026-09-30",
        question: "Which new single-line tab bar direction feels at home in Echo?",
        reasoning: "None. N1, N1R and N4 to N9 were all rejected in the Round 14 answers, and the tab bar went back to Round 9's strip (grey plate, white active tab) on one line with each tab keeping its kind's icon and the database moving to the tooltip.",
        shipped: [],
        supersededBy: "Round 14 · tab bar and pages",
        options: [
            LabDecisionOption(
                name: "Rejected: none of these directions",
                isWinner: false,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabRound13TabBar.swift", "LabRound13Tabs.swift"]
            ) {
                LabRound13Playground()
            }
        ]
    )
}

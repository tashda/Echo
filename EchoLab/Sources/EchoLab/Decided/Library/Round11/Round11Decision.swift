import SwiftUI

extension LabDecision {
    /// Round 11 · tab bar. The specimen is the round's playground as it was when decided.
    static let round11 = LabDecision(
        id: "round11-tab-bar",
        area: "Tabs",
        title: "Round 11 · tab bar",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "The glass tab bar felt weaker than the old strip and its inactive tabs too light. Which design?",
        reasoning: "First T2, filled tabs inside the glass capsule, with T7's two lines to explore; corrected by the owner to T1 (Safari) together with T7's two lines. Eight designs were compared beside today's glass and Classic (T1 Safari, T2 filled, T3 separate pills, T4 server colour, T5 hugging, T6 underline, T7 two-line, T8 accent active). Superseded on 2026-09-30 when the owner went back to Round 9's strip on one line.",
        shipped: ["Classic tab bar kept as fallback"],
        supersededBy: "Round 14 · tab bar and pages",
        options: [
            LabDecisionOption(
                name: "T1 with two lines",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabRound11TabBar.swift", "LabRound11Tabs.swift"]
            ) {
                LabRound11Playground()
            }
        ]
    )
}

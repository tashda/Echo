import SwiftUI

extension LabDecision {
    /// Round 12 · two-line tabs. The specimen is the round's playground as it was when decided.
    static let round12 = LabDecision(
        id: "round12-two-line-tabs",
        area: "Tabs",
        title: "Round 12 · two-line tabs",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "How should the two-line version of the tab bar look?",
        reasoning: "T1 with two lines (the title over the database, the timer while running), inactive tabs with no fill, full-strength titles and hairline dividers, the active tab a raised white pill, every tab showing its kind's icon (a spinner while running), and L2's icon. The bar became 10pt taller. No more lab rounds for the tab bar were planned; the Round 14 answers then went back to one line.",
        shipped: ["glass tab bar"],
        supersededBy: "Round 14 · tab bar and pages",
        options: [
            LabDecisionOption(
                name: "T1 with two lines and L2's icon",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabRound12TwoLineTabs.swift"]
            ) {
                LabRound12Playground()
            }
        ]
    )
}

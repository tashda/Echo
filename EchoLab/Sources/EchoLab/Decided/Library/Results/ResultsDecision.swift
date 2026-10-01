import SwiftUI

extension LabDecision {
    /// Results grid. The specimen is the round's playground as it was when decided.
    static let results = LabDecision(
        id: "results-grid",
        area: "Results",
        title: "Results grid",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "How does the results card look, and how does the selection show?",
        reasoning: "Settled in the earlier rounds (see Design/decisions.md): the results card follows the editor card's tokens, and the selection is drawn as an outline around the selected range. Results grow up out of the footer (round 10) and fold back into it smoothly. The detailed reasoning for the selection outline was not written into the decision log.",
        shipped: ["results card", "AppKit grid"],
        supersededBy: nil,
        options: [
            LabDecisionOption(
                name: "Range outline selection",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabResults.swift"]
            ) {
                LabResultsPlayground()
            }
        ]
    )
}

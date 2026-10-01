import SwiftUI

extension LabDecision {
    /// Tree · sticky header. The specimen is the round's playground as it was when decided.
    static let tree = LabDecision(
        id: "tree-sticky-header",
        area: "Explorer tree",
        title: "Tree · sticky header",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "What happens to the server header when the tree scrolls?",
        reasoning: "Round 6 chose a glass card header: once a server's own header scrolls away, server › database pins at the top of its card on Liquid Glass with the card's rounded top corners and the rows blurring through it (glass is allowed because it holds controls). Round 10 then removed the pinned path header altogether (P1), with its blur and its setting.",
        shipped: [],
        supersededBy: "Round 10 · footer and database switcher (P1 removed the pinned header)",
        options: [
            LabDecisionOption(
                name: "Glass card header, later removed",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabTree.swift"]
            ) {
                LabTreePlayground()
            }
        ]
    )
}

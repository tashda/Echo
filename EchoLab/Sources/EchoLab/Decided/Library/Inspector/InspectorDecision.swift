import SwiftUI

extension LabDecision {
    /// Inspector. The specimen is the round's playground as it was when decided.
    static let inspector = LabDecision(
        id: "inspector-column",
        area: "Inspector",
        title: "Inspector",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "Where and how should the inspector appear?",
        reasoning: "IN1, a column of cards on the canvas, mirroring the tree. Rejected IN2 (a floating card), IN3 (inside the results card) and IN4 (native, restyled). Phase 9 of the plan was rewritten around it. Round 15 revisits how the inspector looks.",
        shipped: ["InspectorCard", "plan Phase 9"],
        supersededBy: nil,
        options: [
            LabDecisionOption(
                name: "Column of cards",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabInspector.swift"]
            ) {
                LabInspectorPlayground()
            }
        ]
    )
}

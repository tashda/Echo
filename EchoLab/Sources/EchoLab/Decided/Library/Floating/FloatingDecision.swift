import SwiftUI

extension LabDecision {
    /// Toasts and notifications. The specimen is the round's playground as it was when decided.
    static let floating = LabDecision(
        id: "toasts-and-notifications",
        area: "Notifications",
        title: "Toasts and notifications",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "How should toasts and the notification history look?",
        reasoning: "All Liquid Glass, melting together (they are floating controls, so glass is allowed). The decision log has no separate entry for the reasoning; the page is the record. Round 15's notifications page reopens this area.",
        shipped: ["StatusToastView", "notification history"],
        supersededBy: nil,
        options: [
            LabDecisionOption(
                name: "Glass toasts and history",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabFloating.swift"]
            ) {
                LabFloatingPlayground()
            }
        ]
    )
}

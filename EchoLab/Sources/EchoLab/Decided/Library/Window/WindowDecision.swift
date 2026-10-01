import SwiftUI

extension LabDecision {
    /// Window · canvas and cards. The specimen is the round's playground as it was when decided.
    static let window = LabDecision(
        id: "window-canvas-and-cards",
        area: "Window and footer",
        title: "Window · canvas and cards",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "How is the whole window built: canvas, rail, tree and cards?",
        reasoning: "Settled over review rounds 3 to 8. Every panel is an opaque card on the window canvas with the editor card's tokens (fill, edge, workspaceCard shadow); glass is only for controls, never for cards, because the tree is content and glass over a flat canvas has nothing to refract. Card corners are 16pt by default (the macOS window corner as measured), with a Card Corners setting of 10, 12, 16, 20 or 26pt. Each server's tree sits on its own card, the tree stops one gutter above the window edge with a rounded end, and the tree only shows when it has content. Welcome and server pages sit on the canvas with no card. See Design/decisions.md, entries of 2026-09-29.",
        shipped: ["workspaceCard()", "LayoutTokens.Workspace", "Card Corners setting"],
        supersededBy: nil,
        options: [
            LabDecisionOption(
                name: "Canvas with opaque cards",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabWindow.swift"]
            ) {
                LabWindowPlayground()
            }
        ]
    )
}

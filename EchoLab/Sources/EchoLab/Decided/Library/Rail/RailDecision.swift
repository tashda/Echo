import SwiftUI

extension LabDecision {
    /// Server rail. The specimen is the round's playground as it was when decided.
    static let rail = LabDecision(
        id: "rail-servers",
        area: "Window and footer",
        title: "Server rail",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "How should the server rail look and behave?",
        reasoning: "The + returns to the rail as the last item of the server pill and opens the connections menu, replacing the toolbar's Connections button (Recent and Quick Connect stay in the toolbar): with one server the pill held a single item and read as a double border. The selection disc is inset 3pt inside its item so it never echoes the pill's edge. Connecting and failed servers come last in rail order.",
        shipped: ["server rail", "LayoutTokens.Workspace rail values"],
        supersededBy: nil,
        options: [
            LabDecisionOption(
                name: "+ in the pill, inset selection disc",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabRail.swift"]
            ) {
                LabRailPlayground()
            }
        ]
    )
}

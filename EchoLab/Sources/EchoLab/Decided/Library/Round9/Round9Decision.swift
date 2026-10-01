import SwiftUI

extension LabDecision {
    /// Round 9 · footer, scroll bar and tabs. The specimen is the round's playground as it was when decided.
    static let round9 = LabDecision(
        id: "round9-footer-scroller-tabs",
        area: "Window and footer",
        title: "Round 9 · footer, scroll bar and tabs",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "What sits behind the footer, where does the footer sit, does the tree show a scroll bar, and how should the tab bar look?",
        reasoning: "FB1 soft blur (BackdropEdgeBlur over the AppKit grid and editor) behind the footer; FP1, the footer lifted 4pt; SB3, no tree scroll bar, with a Show Scroll Bar setting off by default; TB1, one glass capsule with + inside, with the old strip kept as Classic because the owner was not fully sold. Rejected: SB2 (a scroll bar inside each card), SB4 (position shown in the rail), FP2 (footer inset by the corner radius), TB2 (tabs on the canvas), FB3 (a glass bar with glass pills inside it: glass on glass). The tab bar part was later replaced by round 11, 12 and finally the Round 14 strip.",
        shipped: ["BackdropEdgeBlur", "footer position token", "Settings › Sidebar › Show Scroll Bar"],
        supersededBy: "Round 14 · tab bar and pages (the tab bar choice)",
        options: [
            LabDecisionOption(
                name: "FB1, FP1 and SB3 (the tab bar TB1 was later superseded)",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabRound9.swift", "LabRound9Footer.swift", "LabRound9Scroller.swift", "LabRound9Tabs.swift"]
            ) {
                LabRound9Playground()
            }
        ]
    )
}

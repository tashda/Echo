import SwiftUI

extension LabDecision {
    /// Tree card · S4 Quiet. The specimen is the round's playground as it was when decided.
    static let treeCard = LabDecision(
        id: "tree-card-s4-quiet",
        area: "Explorer tree",
        title: "Tree card · S4 Quiet",
        symbol: "checkmark.circle",
        decidedOn: "2026-09-29",
        question: "The server card is liked, but its content feels dated. How should the tree inside it look?",
        reasoning: "S4 Quiet with the Folders and Dimmed prefix controls: at medium density ordinary rows are 28pt in a 29pt slot, 13pt labels, 13pt light monochrome-rendered symbols, an 8pt icon-to-label gap, 16pt indentation and 8pt corners. No separate disclosure column: a folder's icon becomes a 10pt semibold chevron on hover, and counts appear on hover. Selection is the semantic grey fill with accented icons; server-level groups are ordinary folders. The bold server name and version, the Vivid icon palette and ordered blueprints stay. Replaces the earlier S1 Tahoe and sections choice; S2 Tiles, S3 Structure, S5 Detailed and S6 Path were not chosen.",
        shipped: ["SidebarRowConstants", "ExplorerBlueprint files", "plan Phase 2b"],
        supersededBy: nil,
        options: [
            LabDecisionOption(
                name: "S4 Quiet",
                isWinner: true,
                why: "The round's playground, live, with every option it compared.",
                sourceFiles: ["LabTreeCardData.swift", "LabTreeCardFlattening.swift", "LabTreeCardPlayground.swift", "LabTreeCardRow.swift", "LabTreeCardServerCard.swift", "LabTreeCardStyle.swift"]
            ) {
                LabTreeCardPlayground()
            }
        ]
    )
}

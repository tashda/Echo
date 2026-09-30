import SwiftUI

/// Round 15 · the inspector column, as a `RoundSpec`: three looks, same content.
@MainActor
enum InspectorRound {
    static let spec = RoundSpec(
        exhibits: LabInspectorLook.allCases.map { look in
            RoundSpec.Exhibit(id: look.rawValue, title: look.rawValue, summary: look.summary,
                              designWidth: LabRound15Metrics.columnWidth + SpacingTokens.lg, designHeight: LabRound15Metrics.columnHeight + SpacingTokens.lg) { _ in
                LabInspectorColumn(look: look).padding(SpacingTokens.xs)
            }
        },
        exhibitTopic: ("Which inspector look?",
                       "Scroll each column and look at the edges and shadows, in light and dark.",
                       LabInspectorLook.groupedBoxes.rawValue,
                       "One card avoids the stacked, cut-off shadows of a card per section, and inset groups read like System Settings. A single card with hairlines is plainer but has no grouping.")
    )
}

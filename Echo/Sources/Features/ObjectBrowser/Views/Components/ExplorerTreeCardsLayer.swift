import SwiftUI

/// One card per server behind the rows, each cut to the visible part of the tree. The cards use
/// the editor card's modifier, so they match it exactly (tokens, corners setting, shadow, edge).
struct ExplorerTreeCardsLayer: View {
    let cards: [ExplorerTreeLayout.Card]
    let scroll: ExplorerTreeScrollState
    /// Cards mid dock switch: their edge moves with `edgeAnimation`; every other card moves with
    /// its rows (Design/05-components › Explorer tree › Switching).
    var switchingCardIDs: Set<String> = []
    var edgeAnimation: Animation? = nil

    var body: some View {
        let offset = scroll.offset
        let viewport = scroll.viewportHeight

        ZStack(alignment: .top) {
            ForEach(cards) { card in
                let top = max(card.minY - offset, 0)
                let bottom = min(card.minY + card.height - offset, viewport)
                if bottom - top > SpacingTokens.micro {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: bottom - top)
                        .workspaceCard()
                        .offset(y: top)
                        .animation(switchingCardIDs.contains(card.id) ? edgeAnimation : nil, value: card.height)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

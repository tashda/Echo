import SwiftUI

/// One card per server behind the rows, each cut to the visible part of the tree. The card itself
/// comes from the caller (Echo draws it with the editor card's modifier, so they match exactly).
public struct ExplorerTreeCardsLayer<CardBackground: View>: View {
    let cards: [ExplorerTreeCard]
    let scroll: ExplorerTreeScrollState
    /// Cards mid dock switch: their edge moves with `edgeAnimation`; every other card moves with
    /// its rows (Design/05-components › Explorer tree › Switching).
    let switchingCardIDs: Set<String>
    let edgeAnimation: Animation?
    let card: () -> CardBackground

    public init(cards: [ExplorerTreeCard], scroll: ExplorerTreeScrollState, switchingCardIDs: Set<String> = [],
                edgeAnimation: Animation? = nil, @ViewBuilder card: @escaping () -> CardBackground) {
        self.cards = cards
        self.scroll = scroll
        self.switchingCardIDs = switchingCardIDs
        self.edgeAnimation = edgeAnimation
        self.card = card
    }

    public var body: some View {
        let offset = scroll.offset
        let viewport = scroll.viewportHeight

        ZStack(alignment: .top) {
            ForEach(cards) { card in
                let top = max(card.minY - offset, 0)
                let bottom = min(card.minY + card.height - offset, viewport)
                if bottom - top > SpacingTokens.micro {
                    self.card()
                        .frame(maxWidth: .infinity)
                        .frame(height: bottom - top)
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

/// A card's place in the tree, for the cards layer: one per server.
public struct ExplorerTreeCard: Identifiable, Sendable {
    public let id: String
    public let minY: CGFloat
    public let height: CGFloat

    public init(id: String, minY: CGFloat, height: CGFloat) {
        self.id = id
        self.minY = minY
        self.height = height
    }
}

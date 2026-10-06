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
    /// Cards folding or opening (round 30.2, CM2): their edge glides with `foldAnimation` while
    /// their rows fade and are cut by it (`ExplorerTreeFoldTransition`).
    let foldingCardIDs: Set<String>
    let foldAnimation: Animation?
    let card: () -> CardBackground

    public init(cards: [ExplorerTreeCard], scroll: ExplorerTreeScrollState, switchingCardIDs: Set<String> = [],
                edgeAnimation: Animation? = nil, foldingCardIDs: Set<String> = [], foldAnimation: Animation? = nil,
                @ViewBuilder card: @escaping () -> CardBackground) {
        self.cards = cards
        self.scroll = scroll
        self.switchingCardIDs = switchingCardIDs
        self.edgeAnimation = edgeAnimation
        self.foldingCardIDs = foldingCardIDs
        self.foldAnimation = foldAnimation
        self.card = card
    }

    /// A folding card may also be marked as switching (its rows come in under the switch's veil,
    /// round 46); its edge still moves with the fold, on the rows' curve.
    private func animation(for card: ExplorerTreeCard) -> Animation? {
        if foldingCardIDs.contains(card.id) { return foldAnimation }
        if switchingCardIDs.contains(card.id) { return edgeAnimation }
        return nil
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
                        .animation(animation(for: card), value: card.height)
                        // A minimized card leaves and a restored one arrives (round 51, SH5), fading and
                        // settling to 97% from its top edge (round 55).
                        .transition(.opacity.combined(with: .scale(scale: ExplorerTreeCardUnitTransition.settledScale, anchor: .top)))
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

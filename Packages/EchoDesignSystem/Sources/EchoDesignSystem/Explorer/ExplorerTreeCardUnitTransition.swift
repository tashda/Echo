import SwiftUI

/// A minimized card leaves the tree, and a restored one arrives, as one piece (round 55): every
/// row of the card, its banner and dock included, fades and settles to 97% about the card's top
/// centre, the same as the card's background (`ExplorerTreeCardsLayer`), so nothing is left behind
/// at full size while the card shrinks.
public struct ExplorerTreeCardUnitTransition: Transition {
    /// The scale a leaving card settles to (the card background uses it too).
    public static let settledScale: CGFloat = 0.97

    let cardTop: CGFloat
    let rowTop: CGFloat
    let rowHeight: CGFloat

    public init(cardTop: CGFloat, rowTop: CGFloat, rowHeight: CGFloat) {
        self.cardTop = cardTop
        self.rowTop = rowTop
        self.rowHeight = rowHeight
    }

    /// The card's top centre, in the row's own unit space.
    var anchor: UnitPoint {
        UnitPoint(x: 0.5, y: rowHeight > 0 ? (cardTop - rowTop) / rowHeight : 0)
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : Self.settledScale, anchor: anchor)
    }
}

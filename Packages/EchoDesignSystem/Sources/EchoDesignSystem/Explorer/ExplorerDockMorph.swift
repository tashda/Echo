import CoreGraphics
import Foundation

/// Round 57 (HB3, MP0, PS0): while a server card scrolls past the top of the tree, the banner
/// scrolls away with the content and the dock row, the banner's bottom row, morphs into a floating
/// pill. Everything here is a function of how far the tree is scrolled and where the card is, so
/// the morph follows the scroll exactly: stop half-way and it is half-morphed, scroll back and it
/// reverses. Nothing is timed.
///
/// All values are in the tree's content coordinates unless a name says it is in the view's.
public struct ExplorerDockMorph: Equatable, Sendable {
    /// The pill's width once the morph is done, centred in the card.
    public static let pillWidth: CGFloat = 190
    /// The pill's height once the morph is done.
    public static let pillHeight: CGFloat = 30
    /// The pill rests this far from the top of the view (the card's top edge, once scrolled into).
    public static let pillTop: CGFloat = SpacingTokens.xs

    /// The card's top.
    public let cardTop: CGFloat
    /// The banner above the dock: the server row's height.
    public let nameHeight: CGFloat
    /// The dock row's slot, which the layout keeps reserved however far the morph has gone.
    public let dockHeight: CGFloat
    /// The card's bottom, with its bottom padding.
    public let cardBottom: CGFloat

    public init(cardTop: CGFloat, nameHeight: CGFloat, dockHeight: CGFloat, cardBottom: CGFloat) {
        self.cardTop = cardTop
        self.nameHeight = nameHeight
        self.dockHeight = dockHeight
        self.cardBottom = cardBottom
    }

    /// Where the dock row sits when nothing has scrolled.
    public var dockTop: CGFloat { cardTop + nameHeight }

    // MARK: - Progress

    /// How far the card's top is above the view's top; negative while the card is still below it.
    public func scrolledInCard(offset: CGFloat) -> CGFloat { offset - cardTop }

    /// 0 at rest, 1 when the dock row has reached the top of the view: it follows the scroll one
    /// to one over the stretch the dock row travels before it pins (`nameHeight - pillTop`).
    public func progress(offset: CGFloat) -> Double {
        let distance = max(nameHeight - Self.pillTop, 1)
        return Double(min(max(scrolledInCard(offset: offset) / distance, 0), 1))
    }

    /// The same, from where the dock row's top is in the view (`dockTop - offset`): what a scroll
    /// view's geometry gives without knowing the offset.
    public func progress(naturalTop: CGFloat) -> Double {
        progress(offset: dockTop - naturalTop)
    }

    // MARK: - The pill

    /// The pill's width: the card's, narrowing to `pillWidth`.
    public func width(cardWidth: CGFloat, progress: Double) -> CGFloat {
        cardWidth + (min(Self.pillWidth, cardWidth) - cardWidth) * CGFloat(progress)
    }

    /// The pill's height: the dock slot, shrinking to `pillHeight`.
    public func height(progress: Double) -> CGFloat {
        dockHeight + (Self.pillHeight - dockHeight) * CGFloat(progress)
    }

    /// Corners go from square to a capsule with the morph.
    public func cornerRadius(progress: Double) -> CGFloat {
        CGFloat(progress) * height(progress: progress) / 2
    }

    /// The pill's top in the view: where the dock row is, held at `pillTop`, and pushed up and out
    /// by the card's bottom (the next card's top), so it never overlaps the next card's banner.
    public func top(offset: CGFloat) -> CGFloat {
        let height = height(progress: progress(offset: offset))
        let pinned = max(Self.pillTop, dockTop - offset)
        return min(pinned, cardBottom - offset - height - Self.pillTop)
    }

    /// How far to move the dock row from where the scroll view puts it (its top at `naturalTop` in
    /// the view) so it is at `top`.
    public func pinOffset(naturalTop: CGFloat) -> CGFloat {
        top(offset: dockTop - naturalTop) - naturalTop
    }

    /// The pill's bottom in the view, for what has to stay clear of it (the switch's veil).
    public func bottom(offset: CGFloat) -> CGFloat {
        top(offset: offset) + height(progress: progress(offset: offset))
    }
}

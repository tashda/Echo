import SwiftUI

/// One row's slot in the Explorer tree: as wide as the tree, exactly `height` tall, with the row
/// centred in it.
///
/// Every row's height is known from `ExplorerTreeLayout`, so the slot answers the lazy stack's
/// size question without asking the row. With pinned server headers the stack measures every row
/// of a server's card on every scrolled frame; a row behind plain `.frame` modifiers was measured
/// through its whole HStack, which made scrolling a long Tables folder cost about 100 ms a frame
/// (traced 2026-10-01). Being a layout, the slot is also one element to the stack, so the row's
/// own modifiers are never walked when the stack lists its rows.
public struct ExplorerTreeRowSlot: Layout {
    public let height: CGFloat

    public init(height: CGFloat) {
        self.height = height
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = ProposedViewSize(width: bounds.width, height: bounds.height)
        for subview in subviews {
            subview.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: size)
        }
    }

    // The defaults ask every subview; the slot has nothing to align and no spacing of its own.
    public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                                  subviews: Subviews, cache: inout ()) -> CGFloat? {
        nil
    }

    public func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                                  subviews: Subviews, cache: inout ()) -> CGFloat? {
        nil
    }

    public func spacing(subviews: Subviews, cache: inout ()) -> ViewSpacing {
        ViewSpacing()
    }
}

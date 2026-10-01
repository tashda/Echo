import SwiftUI

/// Scroll position and viewport size, read only by the cards layer so scrolling never
/// re-renders the rows.
@Observable @MainActor
public final class ExplorerTreeScrollState {
    public var offset: CGFloat = 0
    public var viewportHeight: CGFloat = 0
    /// Width of the rows, which is narrower than the tree when scroll bars are always shown.
    public var contentWidth: CGFloat = 0
    /// The scroll content's height last time it was laid out, spacer included (round 19, N2).
    public var totalHeight: CGFloat = 0
    @ObservationIgnored public var lastReportedContext: ExplorerTreeTopContext?

    public init() {}
}

public struct ExplorerTreeScrollMetrics: Equatable, Sendable {
    public var offset: CGFloat
    public var viewportHeight: CGFloat
    public var contentWidth: CGFloat
    public var totalHeight: CGFloat = 0

    public init(offset: CGFloat, viewportHeight: CGFloat, contentWidth: CGFloat, totalHeight: CGFloat = 0) {
        self.offset = offset
        self.viewportHeight = viewportHeight
        self.contentWidth = contentWidth
        self.totalHeight = totalHeight
    }
}

/// N2 (round 19): when the list gets shorter, the view doesn't scroll back by itself (which moved
/// every card above). A spacer under the last card keeps the bottom where it was; it gives the
/// room back as you scroll up, and never grows past the last layout, so overscrolling can't
/// stretch it.
public enum ExplorerTreeHold {
    public static func spacerHeight(offset: CGFloat, viewport: CGFloat, contentHeight: CGFloat, previousTotal: CGFloat) -> CGFloat {
        let restingOffset = min(max(offset, 0), max(previousTotal - viewport, 0))
        return max(0, restingOffset + viewport - contentHeight)
    }
}

/// The spacer itself: the only view below the rows that reads the scroll position.
public struct ExplorerTreeHoldSpacer: View {
    let scroll: ExplorerTreeScrollState
    let contentHeight: CGFloat

    public init(scroll: ExplorerTreeScrollState, contentHeight: CGFloat) {
        self.scroll = scroll
        self.contentHeight = contentHeight
    }

    public var body: some View {
        Color.clear.frame(height: ExplorerTreeHold.spacerHeight(
            offset: scroll.offset, viewport: scroll.viewportHeight,
            contentHeight: contentHeight, previousTotal: scroll.totalHeight
        ))
    }
}

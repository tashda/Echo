import SwiftUI

/// Scroll position and viewport size, read by the cards layer, the veil and the pinned headers,
/// so scrolling never re-renders the rows; the rows read only `window`, which moves in steps.
@Observable @MainActor
public final class ExplorerTreeScrollState {
    public var offset: CGFloat = 0
    public var viewportHeight: CGFloat = 0
    /// Width of the rows, which is narrower than the tree when scroll bars are always shown.
    public var contentWidth: CGFloat = 0
    /// The scroll content's height last time it was laid out, spacer included (round 19, N2).
    public var totalHeight: CGFloat = 0
    /// The stretch of the tree the rows are built for; it changes only in steps (ExplorerTreeCanvas).
    public var window = ExplorerTreeWindow.initial
    /// The room held under the last card (N2). Stored, and set only when it changes, so the
    /// spacer (and the stack holding every row) isn't laid out again on every scrolled frame.
    public var holdHeight: CGFloat = 0
    /// The rows' height `holdHeight` was worked out for. While the rows are another height (they
    /// just changed), the spacer works the hold out itself, in the same layout pass.
    public var holdContent: CGFloat = -1
    /// The last metrics from the scroll view, readable without observing them: the spacer uses
    /// them while the rows change, and must not be redrawn by every scrolled frame.
    @ObservationIgnored public private(set) var latest = ExplorerTreeScrollMetrics(offset: 0, viewportHeight: 0, contentWidth: 0)
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

extension ExplorerTreeScrollState {
    /// Remembers what the scroll view reported (see `latest`).
    public func record(_ metrics: ExplorerTreeScrollMetrics) { latest = metrics }

    /// The hold for rows of `contentHeight`, from the last reported metrics.
    public func carriedHold(contentHeight: CGFloat) -> CGFloat {
        ExplorerTreeHold.spacerHeight(offset: latest.offset, viewport: latest.viewportHeight,
                                      contentHeight: contentHeight, previousTotal: latest.totalHeight)
    }

    /// Works the hold out again for the rows' height now; call it after the view scrolls and
    /// whenever the rows change height.
    public func updateHold(contentHeight: CGFloat) {
        let height = ExplorerTreeHold.spacerHeight(offset: offset, viewport: viewportHeight,
                                                   contentHeight: contentHeight, previousTotal: totalHeight)
        if abs(height - holdHeight) > 0.5 { holdHeight = height }
        if holdContent != contentHeight { holdContent = contentHeight }
    }
}

/// The spacer itself, under the rows. It reads only `holdHeight`, which rarely changes. When the
/// rows change height it takes the hold from the metrics the scroll view last reported, in the
/// same layout pass as the rows, so the view is never clamped for a frame and no card moves; the
/// hold then follows the scrolling (`updateHold`).
public struct ExplorerTreeHoldSpacer: View {
    let scroll: ExplorerTreeScrollState
    let contentHeight: CGFloat

    public init(scroll: ExplorerTreeScrollState, contentHeight: CGFloat) {
        self.scroll = scroll
        self.contentHeight = contentHeight
    }

    public var body: some View {
        let height = scroll.holdContent == contentHeight ? scroll.holdHeight : scroll.carriedHold(contentHeight: contentHeight)
        Color.clear.frame(height: height)
    }
}

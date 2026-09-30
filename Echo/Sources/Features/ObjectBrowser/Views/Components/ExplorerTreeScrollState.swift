import SwiftUI

/// Scroll position and viewport size, read only by the cards layer so scrolling never
/// re-renders the rows.
@Observable @MainActor
final class ExplorerTreeScrollState {
    var offset: CGFloat = 0
    var viewportHeight: CGFloat = 0
    /// Width of the rows, which is narrower than the tree when scroll bars are always shown.
    var contentWidth: CGFloat = 0
    /// The scroll content's height last time it was laid out, spacer included (round 19, N2).
    var totalHeight: CGFloat = 0
    @ObservationIgnored var lastReportedContext: ObjectBrowserTopVisibleContext?
}

struct ExplorerTreeScrollMetrics: Equatable {
    var offset: CGFloat
    var viewportHeight: CGFloat
    var contentWidth: CGFloat
    var totalHeight: CGFloat = 0
}

/// N2 (round 19): when the list gets shorter, the view doesn't scroll back by itself (which moved
/// every card above). A spacer under the last card keeps the bottom where it was; it gives the
/// room back as you scroll up, and never grows past the last layout, so overscrolling can't
/// stretch it.
enum ExplorerTreeHold {
    static func spacerHeight(offset: CGFloat, viewport: CGFloat, contentHeight: CGFloat, previousTotal: CGFloat) -> CGFloat {
        let restingOffset = min(max(offset, 0), max(previousTotal - viewport, 0))
        return max(0, restingOffset + viewport - contentHeight)
    }
}

/// The spacer itself: the only view below the rows that reads the scroll position.
struct ExplorerTreeHoldSpacer: View {
    let scroll: ExplorerTreeScrollState
    let contentHeight: CGFloat

    var body: some View {
        Color.clear.frame(height: ExplorerTreeHold.spacerHeight(
            offset: scroll.offset, viewport: scroll.viewportHeight,
            contentHeight: contentHeight, previousTotal: scroll.totalHeight
        ))
    }
}

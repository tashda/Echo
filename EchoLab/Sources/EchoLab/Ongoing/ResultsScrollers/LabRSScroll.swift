import AppKit
import Observation

/// Round 27: where the grid is scrolled sideways, shared between the AppKit grid and the footer's
/// own track (F) or position chip (G), which can also scroll it.
@Observable @MainActor
final class LabRSScroll {
    /// 0 at the left edge, 1 at the right.
    var position: CGFloat = 0
    /// How much of the full width is visible, 0 to 1.
    var visibleFraction: CGFloat = 1
    var firstColumn = 1
    var lastColumn = 1
    var columnCount = 1
    @ObservationIgnored var scrollTo: (CGFloat) -> Void = { _ in }
}

import SwiftUI

/// Scroll position and viewport size, read only by the cards layer so scrolling never
/// re-renders the rows.
@Observable @MainActor
final class ExplorerTreeScrollState {
    var offset: CGFloat = 0
    var viewportHeight: CGFloat = 0
    /// Width of the rows, which is narrower than the tree when scroll bars are always shown.
    var contentWidth: CGFloat = 0
    @ObservationIgnored var lastReportedContext: ObjectBrowserTopVisibleContext?
    @ObservationIgnored var lastReportedTopRowID: String?
}

struct ExplorerTreeScrollMetrics: Equatable {
    var offset: CGFloat
    var viewportHeight: CGFloat
    var contentWidth: CGFloat
}

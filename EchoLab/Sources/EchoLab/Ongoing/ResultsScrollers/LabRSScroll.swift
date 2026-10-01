import AppKit
import Observation

/// Round 27: where the grid is scrolled and where the pointer is, shared between the AppKit grid
/// and the SwiftUI bars, track (F), chip (G) and extras, which can also scroll it.
@Observable @MainActor
final class LabRSScroll {
    /// 0 at the left edge, 1 at the right.
    var position: CGFloat = 0
    /// How much of the full width is visible, 0 to 1.
    var visibleFraction: CGFloat = 1
    var verticalPosition: CGFloat = 0
    var verticalVisibleFraction: CGFloat = 1
    var firstColumn = 1
    var lastColumn = 1
    var columnCount = 1
    var headerHeight: CGFloat = 0
    /// True while scrolling and for a moment after.
    var isScrolling = false
    /// The pointer in the grid's coordinates (top left origin), nil when it is outside.
    var pointer: CGPoint?
    @ObservationIgnored var scrollTo: (CGFloat) -> Void = { _ in }
    @ObservationIgnored var scrollVerticallyTo: (CGFloat) -> Void = { _ in }
    @ObservationIgnored private var restTask: Task<Void, Never>?

    func noteScrolled() {
        if !isScrolling { isScrolling = true }
        restTask?.cancel()
        restTask = Task(name: "lab-rs-rest") { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.isScrolling = false
        }
    }
}

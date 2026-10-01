import AppKit

/// The footer floating over the bottom of an AppKit scroll view (the results grid, the editor):
/// room for the last rows to scroll clear of it, the soft blur under it (round 9, FB1), the scroll
/// bars just above its pills (round 27: E, the system's bar, R2), and for grids, soft edges where
/// more columns wait (round 27, X1).
///
/// The blur and the soft edges live in the clip view, between the rows and the scroll bars, so
/// the bars are never blurred.
@MainActor
final class FooterScrollOverlay {
    private weak var scrollView: NSScrollView?
    private let blur: BackdropEdgeBlur
    private let sideFades: ScrollSideFades?
    private var footerHeight: CGFloat = -1
    private var edgeColor: NSColor = .textBackgroundColor

    init(scrollView: NSScrollView, softEdges: Bool) {
        self.scrollView = scrollView
        blur = BackdropEdgeBlur(container: scrollView.contentView)
        sideFades = softEdges ? ScrollSideFades(clipView: scrollView.contentView) : nil
    }

    /// The footer's height over the scroll view; zero removes the room, the blur and the lift.
    func update(footerHeight height: CGFloat) {
        guard let scrollView, height != footerHeight else { return }
        footerHeight = height
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets.bottom = height
        scrollView.scrollerInsets.bottom = LayoutTokens.Footer.scrollerInset(overFooter: height)
        blur.update(
            edge: .bottom,
            height: height > 0 ? height + LayoutTokens.EdgeBlur.fade : 0,
            radii: height > 0 ? LayoutTokens.EdgeBlur.radii : []
        )
        sideFades?.update(color: edgeColor, bottomRoom: height)
    }

    /// The card's colour, which the soft edges fade into.
    func update(edgeColor color: NSColor) {
        edgeColor = color
        sideFades?.update(color: color, bottomRoom: max(footerHeight, 0))
    }
}

import AppKit

/// The footer floating over the bottom of an AppKit scroll view (the results grid, the editor):
/// room for the last rows to scroll clear of it, the scroll bars just above its pills (round 27:
/// E, the system's bar, R2) and the bar as wide as the footer (L2). The rows soften under the footer's material (round 44,
/// `FooterMaterialBlur`, drawn by the card), so the scroll view's `ScrollBarBlur` stays off here.
@MainActor
final class FooterScrollOverlay {
    private weak var scrollView: NSScrollView?
    private let scrollBarBlur: ScrollBarBlur
    private var footerHeight: CGFloat = -1

    /// `barLeadingInCard` is how far the scroll view starts from its card's left edge (the row
    /// numbers' width beside a grid), so the bar can line up with the footer.
    init(scrollView: NSScrollView, barLeadingInCard: CGFloat = 0) {
        self.scrollView = scrollView
        scrollBarBlur = ScrollBarBlur.attachment(for: scrollView)
        scrollBarBlur.barLeadingInCard = barLeadingInCard
    }

    /// The footer's height over the scroll view; zero removes the room, the resting blur and the lift.
    func update(footerHeight height: CGFloat) {
        guard let scrollView, height != footerHeight else { return }
        footerHeight = height
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets.bottom = height
        scrollView.scrollerInsets.bottom = LayoutTokens.Footer.scrollerInset(overFooter: height)
        scrollBarBlur.footerRoom = height
        scrollView.tile()
    }

    /// How far the scroll view starts from its card's left edge.
    func update(barLeadingInCard leading: CGFloat) {
        scrollBarBlur.barLeadingInCard = leading
    }
}

import AppKit
import ObjectiveC

/// The horizontal bar of the results grid and the editor (`FooterScrollOverlay` attaches it): the
/// bar runs as wide as the footer (round 27, L2), and without a footer a blur rises past it while it
/// shows (U5). Under a footer the footer's material softens the rows instead (round 44,
/// `FooterMaterialBlur`). No other scroll view in Echo gets it: the owner took back the blur behind
/// every bar after round 44.
@MainActor
final class ScrollBarBlur {
    private weak var scrollView: NSScrollView?
    private let blur: BackdropEdgeBlur
    private var observer: NSObjectProtocol?
    private var settleTask: Task<Void, Never>?
    private var lastOrigin: NSPoint?

    /// The footer's room under the content; the blur rests that tall, with its fade above.
    var footerRoom: CGFloat = 0 { didSet { if oldValue != footerRoom { refresh() } } }
    /// L2: how far the scroll view starts from its card's left edge, so the bar can run from the
    /// footer's left padding to its right. Nil leaves the bar where AppKit puts it.
    var barLeadingInCard: CGFloat? { didSet { if oldValue != barLeadingInCard { scrollView?.tile() } } }

    private init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        blur = BackdropEdgeBlur(container: scrollView.contentView)
        let clip = scrollView.contentView
        clip.postsBoundsChangedNotifications = true
        observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clip, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.scrolled() }
        }
    }

    isolated deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - Attaching

    private nonisolated(unsafe) static var associationKey: UInt8 = 0

    /// The scroll view's blur, made on first use.
    static func attachment(for scrollView: NSScrollView) -> ScrollBarBlur {
        if let existing = existing(for: scrollView) { return existing }
        let made = ScrollBarBlur(scrollView: scrollView)
        objc_setAssociatedObject(scrollView, &associationKey, made, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return made
    }

    static func existing(for scrollView: NSScrollView) -> ScrollBarBlur? {
        objc_getAssociatedObject(scrollView, &associationKey) as? ScrollBarBlur
    }

    /// Called after every scroll view lays out its bars (`ScrollBarBlurHook`).
    /// Only scroll views that asked for it (the results grid and the editor, through
    /// `FooterScrollOverlay`): the owner took back the blur behind every other bar in Echo (after
    /// round 44; it looked wrong in tool tabs such as Agent Jobs).
    static func scrollViewDidTile(_ scrollView: NSScrollView) {
        existing(for: scrollView)?.didTile()
    }

    // MARK: - Layout

    private func didTile() {
        stretchBar()
        refresh()
    }

    /// L2: the bar runs from the footer's left padding to its right, over the row numbers too.
    private func stretchBar() {
        guard footerRoom > 0, let leading = barLeadingInCard, let scrollView, let bar = scrollView.horizontalScroller else { return }
        var frame = bar.frame
        frame.origin.x = SpacingTokens.sm - leading
        frame.size.width = max(scrollView.bounds.width + leading - SpacingTokens.sm * 2, 0)
        if frame != bar.frame { bar.frame = frame }
    }

    /// The blur's heights above the visible bottom, raised past the bar's widest thumb. Under a
    /// footer there is none: the footer's material softens the rows and reaches past the bar
    /// (round 44, `FooterMaterialBlur`).
    private func refresh() {
        guard let scrollView else { return }
        guard footerRoom == 0 else {
            blur.update(edge: .bottom, height: 0, radii: [])
            return
        }
        let fade = LayoutTokens.EdgeBlur.fade
        let rest: CGFloat = 0
        var raised = rest
        if let thumbBottom = Self.thumbBottom(in: scrollView) {
            raised = max(rest, thumbBottom + LayoutTokens.Footer.overlayThumbMaxHeight + fade)
        }
        blur.update(edge: .bottom, restHeight: rest, raisedHeight: raised, radii: LayoutTokens.EdgeBlur.radii)
    }

    /// How far the horizontal bar's thumb sits above the clip view's bottom edge, if it has one.
    static func thumbBottom(in scrollView: NSScrollView) -> CGFloat? {
        guard scrollView.hasHorizontalScroller, scrollView.scrollerStyle == .overlay,
              let bar = scrollView.horizontalScroller, !bar.isHidden else { return nil }
        let clip = scrollView.contentView.frame
        let gap = scrollView.isFlipped ? clip.maxY - bar.frame.maxY : bar.frame.minY - clip.minY
        return gap + LayoutTokens.Footer.overlayThumbInset
    }

    // MARK: - Scrolling

    /// Whether the content is wider than the view, so the bar shows when it scrolls.
    private var scrollsSideways: Bool {
        guard let scrollView, let document = scrollView.documentView, Self.thumbBottom(in: scrollView) != nil else { return false }
        return document.frame.width > scrollView.contentView.bounds.width + 0.5
    }

    private func scrolled() {
        guard let scrollView else { return }
        let origin = scrollView.contentView.bounds.origin
        guard origin != lastOrigin else { return }
        lastOrigin = origin
        guard scrollsSideways else { return }
        blur.setRaised(true)
        settleTask?.cancel()
        settleTask = Task(name: "scroll-bar-blur-settle") { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(LayoutTokens.EdgeBlur.raisedHold))
            guard !Task.isCancelled else { return }
            self?.blur.setRaised(false)
        }
    }
}

/// Runs an attached `ScrollBarBlur` after every `NSScrollView.tile()`, the point where AppKit lays
/// out its bars, so the bar can be stretched and its blur placed. Installed once at launch.
@MainActor
enum ScrollBarBlurHook {
    private static var isInstalled = false

    static func install() {
        guard !isInstalled,
              let original = class_getInstanceMethod(NSScrollView.self, #selector(NSScrollView.tile)),
              let hooked = class_getInstanceMethod(NSScrollView.self, #selector(NSScrollView.echo_tileWithScrollBarBlur))
        else { return }
        method_exchangeImplementations(original, hooked)
        isInstalled = true
    }
}

extension NSScrollView {
    /// After the exchange this name runs AppKit's own `tile()`, then attaches the blur.
    @objc fileprivate func echo_tileWithScrollBarBlur() {
        echo_tileWithScrollBarBlur()
        ScrollBarBlur.scrollViewDidTile(self)
    }
}

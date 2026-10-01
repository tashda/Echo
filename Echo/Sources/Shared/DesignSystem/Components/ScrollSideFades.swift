import AppKit

/// Soft edges where more columns wait (round 27, X1): the rows fade into the card's colour at a
/// side the view can still scroll towards, and stop fading at the end, as the footer's blur does
/// at the bottom.
///
/// The fades live in the scroll view's clip view, under the scroll bars, and follow the visible
/// area as it scrolls. They cover the rows from the top down to the footer's room.
@MainActor
final class ScrollSideFades {
    private weak var clip: NSClipView?
    private let leading = ScrollSideFadeView(towardsLeading: true)
    private let trailing = ScrollSideFadeView(towardsLeading: false)
    private var bottomRoom: CGFloat = 0
    private var observers: [NSObjectProtocol] = []

    init(clipView: NSClipView) {
        clip = clipView
        clipView.addSubview(leading)
        clipView.addSubview(trailing)
        clipView.postsBoundsChangedNotifications = true
        clipView.postsFrameChangedNotifications = true
        observers = [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: clipView, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated { self?.place() }
            }
        }
        place()
    }

    isolated deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// The card's colour the rows fade into, and the room the footer takes at the bottom.
    func update(color: NSColor, bottomRoom: CGFloat) {
        leading.color = color
        trailing.color = color
        self.bottomRoom = bottomRoom
        place()
    }

    /// Which sides fade: a side fades while the view can still scroll towards it.
    nonisolated static func fadingSides(visible: NSRect, contentWidth: CGFloat) -> (leading: Bool, trailing: Bool) {
        (visible.minX > 0.5, visible.maxX < contentWidth - 0.5)
    }

    /// How strongly each side fades: in full while at least `width` of content waits beyond it, less
    /// as the end comes closer, and not at all at the end, so the last column is never veiled (owner,
    /// after round 47: the sides stayed white when scrolled all the way).
    nonisolated static func fadeStrengths(visible: NSRect, contentWidth: CGFloat, width: CGFloat) -> (leading: CGFloat, trailing: CGFloat) {
        guard width > 0 else { return (0, 0) }
        let leading = min(max(visible.minX / width, 0), 1)
        let trailing = min(max((contentWidth - visible.maxX) / width, 0), 1)
        return (leading, trailing)
    }

    private func place() {
        guard let clip else { return }
        let area = clip.bounds
        let width = LayoutTokens.EdgeBlur.sideFadeWidth
        let height = max(area.height - bottomRoom, 0)
        let top = clip.isFlipped ? area.minY : area.minY + bottomRoom
        leading.frame = NSRect(x: area.minX, y: top, width: width, height: height)
        trailing.frame = NSRect(x: area.maxX - width, y: top, width: width, height: height)
        let strengths = Self.fadeStrengths(visible: area, contentWidth: clip.documentView?.frame.width ?? 0, width: width)
        leading.setStrength(strengths.leading)
        trailing.setStrength(strengths.trailing)
    }
}

/// One soft edge: the card's colour fading out towards the rows.
final class ScrollSideFadeView: NSView {
    private let towardsLeading: Bool
    private let gradient = CAGradientLayer()
    var color: NSColor = .textBackgroundColor { didSet { applyColor() } }

    init(towardsLeading: Bool) {
        self.towardsLeading = towardsLeading
        super.init(frame: .zero)
        wantsLayer = true
        gradient.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(gradient)
        gradient.startPoint = CGPoint(x: towardsLeading ? 0 : 1, y: 0.5)
        gradient.endPoint = CGPoint(x: towardsLeading ? 1 : 0, y: 0.5)
        alphaValue = 0
        applyColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Decoration only: clicks and scrolling go to the rows underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }

    /// 0 to 1, following the scroll position (no animation: it is as wide as the fade itself).
    func setStrength(_ strength: CGFloat) {
        guard abs(alphaValue - strength) > 0.005 else { return }
        alphaValue = strength
    }

    private func applyColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            gradient.colors = [color.cgColor, color.withAlphaComponent(0).cgColor]
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColor()
    }
}

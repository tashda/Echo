import AppKit

/// A real, progressive blur of the AppKit content under one edge of a container (the results
/// grid, the editor, any table with a horizontal scroll bar), strongest at the edge and fading to
/// sharp away from it, with no tint.
///
/// It adds a few views whose Core Image background blur grows towards the edge, each masked to
/// stop a little further from it, along a smooth S curve so no step reads as a line (round 27).
/// A background filter only sees the content of its own superview, so the views go straight into
/// the container, above the AppKit view they blur. SwiftUI content isn't picked up.
///
/// The container can be a scroll view's clip view (round 27): the views then sit between the
/// rows and the scroll bars, so a bar over the blur isn't blurred, and they follow the visible
/// area as it scrolls. Inside the scroll view itself a background filter sees nothing.
///
/// The blur rests at one height and can rise to another (`setRaised`), as it does past a
/// horizontal scroll bar while the bar shows (round 27, U5). The views keep the taller height;
/// only their masks move, animated by Core Animation, so the motion doesn't depend on the main
/// thread.
@MainActor
final class BackdropEdgeBlur {
    enum Edge { case top, bottom }

    private weak var container: NSView?
    private var layerViews: [BackdropEdgeBlurLayerView] = []
    private var edge: Edge = .bottom
    private var radii: [CGFloat] = []
    private var restHeight: CGFloat = -1
    private var raisedHeight: CGFloat = 0
    private(set) var isRaised = false
    private var observers: [NSObjectProtocol] = []
    private var hideTask: Task<Void, Never>?

    init(container: NSView) {
        self.container = container
        if let clip = container as? NSClipView {
            clip.postsBoundsChangedNotifications = true
            clip.postsFrameChangedNotifications = true
            observers = [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification].map { name in
                NotificationCenter.default.addObserver(forName: name, object: clip, queue: nil) { [weak self] _ in
                    MainActor.assumeIsolated { self?.place() }
                }
            }
        }
    }

    isolated deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        layerViews.forEach { $0.removeFromSuperview() }
    }

    /// Places the blur along `edge`, `height` tall; an empty `radii` removes it.
    func update(edge: Edge, height: CGFloat, radii: [CGFloat]) {
        update(edge: edge, restHeight: height, raisedHeight: height, radii: radii)
    }

    /// Places the blur along `edge`: `restHeight` tall, rising to `raisedHeight` while raised.
    func update(edge: Edge, restHeight: CGFloat, raisedHeight: CGFloat, radii: [CGFloat]) {
        guard let container else { return }
        var rebuilt = false
        if edge != self.edge || radii != self.radii || layerViews.count != radii.count {
            self.edge = edge
            self.radii = radii
            layerViews.forEach { $0.removeFromSuperview() }
            layerViews = radii.enumerated().map { index, radius in
                let share = 1 - CGFloat(index) / CGFloat(max(radii.count, 1))
                let view = BackdropEdgeBlurLayerView(radius: radius, share: share)
                container.addSubview(view)
                return view
            }
            rebuilt = true
        }
        let raised = max(raisedHeight, restHeight)
        guard rebuilt || restHeight != self.restHeight || raised != self.raisedHeight else { return }
        self.restHeight = restHeight
        self.raisedHeight = raised
        place()
        applyReach(animated: false)
    }

    /// Raises the blur to its raised height, or lets it settle back, animated.
    func setRaised(_ raised: Bool) {
        guard raised != isRaised else { return }
        isRaised = raised
        applyReach(animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    private var fullHeight: CGFloat { max(restHeight, raisedHeight, 0) }
    private var reach: CGFloat { max(isRaised ? raisedHeight : restHeight, 0) }

    /// Puts the views along the edge of the container's visible area. A clip view's bounds
    /// move as it scrolls, so its views are placed again on every scroll.
    private func place() {
        guard let container else { return }
        let area = container.bounds
        let height = fullHeight
        // In a flipped container y = 0 is the top edge; otherwise it's the bottom edge.
        let atZero = (edge == .top) == container.isFlipped
        let follows = container is NSClipView
        for view in layerViews {
            view.edge = edge
            view.frame = NSRect(x: area.minX, y: atZero ? area.minY : area.maxY - height, width: area.width, height: height)
            view.autoresizingMask = follows ? [] : edge == .top
                ? [.width, container.isFlipped ? .maxYMargin : .minYMargin]
                : [.width, container.isFlipped ? .minYMargin : .maxYMargin]
        }
    }

    /// Moves every step's mask to the current reach. A blur with nothing to show is hidden once
    /// it has settled, so a table at rest pays nothing for it.
    private func applyReach(animated: Bool) {
        hideTask?.cancel()
        let reach = reach
        let duration = animated ? (isRaised ? LayoutTokens.EdgeBlur.raiseDuration : LayoutTokens.EdgeBlur.settleDuration) : 0
        if reach > 0 { layerViews.forEach { $0.isHidden = false } }
        for view in layerViews {
            view.setReach(reach, of: fullHeight, duration: duration)
        }
        guard reach == 0 else { return }
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self, self.reach == 0 else { return }
            self.layerViews.forEach { $0.isHidden = true }
        }
    }
}

/// One step of `BackdropEdgeBlur`: a Gaussian blur of what's behind it, masked from its edge out
/// to `share` of the blur's reach, where it fades out along a smooth S curve.
final class BackdropEdgeBlurLayerView: NSView {
    var edge: BackdropEdgeBlur.Edge = .bottom {
        didSet { if oldValue != edge { needsLayout = true } }
    }
    private let share: CGFloat
    private let mask = CAGradientLayer()

    /// The mask's alphas from the edge out: solid, then an S curve (smoothstep at quarters) to clear.
    nonisolated static let fadeAlphas: [CGFloat] = [1, 1, 0.84375, 0.5, 0.15625, 0]

    init(radius: CGFloat, share: CGFloat) {
        self.share = share
        super.init(frame: .zero)
        wantsLayer = true
        layerUsesCoreImageFilters = true
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setDefaults()
            blur.setValue(radius, forKey: kCIInputRadiusKey)
            backgroundFilters = [blur]
        }
        mask.colors = Self.fadeAlphas.map { NSColor.black.withAlphaComponent($0).cgColor }
        mask.locations = Self.locations(reach: 0, of: 1, share: share).map { NSNumber(value: Double($0)) }
        layer?.mask = mask
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Decoration only: clicks and scrolling go to the content underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.frame = bounds
        // Layer coordinates run bottom-up unless the layer is flipped.
        let flipped = layer?.isGeometryFlipped ?? false
        let edgeAtZero = (edge == .bottom) != flipped
        mask.startPoint = CGPoint(x: 0.5, y: edgeAtZero ? 0 : 1)
        mask.endPoint = CGPoint(x: 0.5, y: edgeAtZero ? 1 : 0)
        CATransaction.commit()
    }

    /// Moves the mask so this step reaches `share` of `reach`, in a view `height` tall.
    func setReach(_ reach: CGFloat, of height: CGFloat, duration: Double) {
        let target = Self.locations(reach: reach, of: height, share: share).map { NSNumber(value: Double($0)) }
        let from = mask.presentation()?.locations ?? mask.locations
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.locations = target
        CATransaction.commit()
        guard duration > 0, let from else { return }
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = from
        animation.toValue = target
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
        mask.add(animation, forKey: "reach")
    }

    /// Where the mask's stops sit, as shares of the view's height from the edge: solid up to where
    /// this step starts fading, then the S curve to clear at `share` of `reach`.
    nonisolated static func locations(reach: CGFloat, of height: CGFloat, share: CGFloat) -> [CGFloat] {
        guard height > 0 else { return Array(repeating: 0, count: fadeAlphas.count) }
        let top = min(max(reach * share / height, 0), 1)
        let start = top * (1 - LayoutTokens.EdgeBlur.step)
        let span = top - start
        return [0, start, start + span * 0.25, start + span * 0.5, start + span * 0.75, top]
    }
}

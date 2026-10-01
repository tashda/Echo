import AppKit

/// A real, progressive blur of the AppKit content under one edge of a container (the results
/// grid, the editor), strongest at the edge and fading to sharp away from it, with no tint.
///
/// It adds a few views whose Core Image background blur grows towards the edge, each masked to
/// stop a little further from it. A background filter only sees the content of its own
/// superview, so the views go straight into the container, above the AppKit view they blur.
/// SwiftUI content isn't picked up.
///
/// The container can be a scroll view's clip view (round 27): the views then sit between the
/// rows and the scroll bars, so a bar over the footer isn't blurred, and they follow the visible
/// area as it scrolls. Inside the scroll view itself a background filter sees nothing.
@MainActor
final class BackdropEdgeBlur {
    enum Edge { case top, bottom }

    private weak var container: NSView?
    private var layerViews: [BackdropEdgeBlurLayerView] = []
    private var edge: Edge = .bottom
    private var radii: [CGFloat] = []
    private var height: CGFloat = 0
    private var observers: [NSObjectProtocol] = []

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
    }

    /// Places the blur along `edge`, `height` tall; an empty `radii` removes it.
    func update(edge: Edge, height: CGFloat, radii: [CGFloat]) {
        guard let container else { return }
        if edge != self.edge || radii != self.radii || layerViews.count != radii.count {
            self.edge = edge
            self.radii = radii
            layerViews.forEach { $0.removeFromSuperview() }
            layerViews = radii.enumerated().map { index, radius in
                let reach = 1 - CGFloat(index) / CGFloat(max(radii.count, 1))
                let view = BackdropEdgeBlurLayerView(radius: radius, reach: reach)
                container.addSubview(view)
                return view
            }
        }
        self.height = height
        place()
    }

    /// Puts the views along the edge of the container's visible area. A clip view's bounds
    /// move as it scrolls, so its views are placed again on every scroll.
    private func place() {
        guard let container else { return }
        let area = container.bounds
        // In a flipped container y = 0 is the top edge; otherwise it's the bottom edge.
        let atZero = (edge == .top) == container.isFlipped
        let follows = container is NSClipView
        for view in layerViews {
            view.edge = edge
            view.frame = NSRect(
                x: area.minX,
                y: atZero ? area.minY : area.maxY - height,
                width: area.width,
                height: height
            )
            view.autoresizingMask = follows ? [] : edge == .top
                ? [.width, container.isFlipped ? .maxYMargin : .minYMargin]
                : [.width, container.isFlipped ? .minYMargin : .maxYMargin]
        }
    }
}

/// One step of `BackdropEdgeBlur`: a Gaussian blur of what's behind it, masked from its edge
/// out to `reach` (a share of its height).
final class BackdropEdgeBlurLayerView: NSView {
    var edge: BackdropEdgeBlur.Edge = .bottom {
        didSet { if oldValue != edge { needsLayout = true } }
    }
    private let reach: CGFloat

    init(radius: CGFloat, reach: CGFloat) {
        self.reach = reach
        super.init(frame: .zero)
        wantsLayer = true
        layerUsesCoreImageFilters = true
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setDefaults()
            blur.setValue(radius, forKey: kCIInputRadiusKey)
            backgroundFilters = [blur]
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Decoration only: clicks and scrolling go to the content underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        let mask = CAGradientLayer()
        mask.frame = bounds
        mask.colors = [NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        mask.locations = [
            0,
            NSNumber(value: Double(max(reach - LayoutTokens.EdgeBlur.step, 0))),
            NSNumber(value: Double(reach)),
        ]
        // Layer coordinates run bottom-up unless the layer is flipped.
        let flipped = layer?.isGeometryFlipped ?? false
        let edgeAtZero = (edge == .bottom) != flipped
        mask.startPoint = CGPoint(x: 0.5, y: edgeAtZero ? 0 : 1)
        mask.endPoint = CGPoint(x: 0.5, y: edgeAtZero ? 1 : 0)
        layer?.mask = mask
    }
}

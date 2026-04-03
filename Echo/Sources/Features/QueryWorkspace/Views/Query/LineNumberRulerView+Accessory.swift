#if os(macOS)
import AppKit
import SwiftUI
import Combine

final class CompletionAccessoryView: NSView {
    struct Layout {
        static let padding = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        static let cornerRadius: CGFloat = 6
        static let strokeWidth: CGFloat = 1
    }

    var onActivate: (() -> Void)?
    private(set) var isVisible: Bool = false

    private var trackingArea: NSTrackingArea?
    private var hostingView: NSHostingView<GlowFrameView>?
    private var isHovering = false {
        didSet { refreshRootView() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
        setupHostingView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(for textRect: NSRect) {
        let pad = Layout.padding
        let frame = NSRect(
            x: textRect.origin.x - pad.left,
            y: textRect.origin.y - pad.bottom,
            width: textRect.size.width + pad.left + pad.right,
            height: textRect.size.height + pad.top + pad.bottom
        ).integral
        if self.frame != frame {
            self.frame = frame
        }
        needsLayout = true
        isHovering = false
        isVisible = true
        refreshRootView()
        updateTrackingAreas()
    }

    override func layout() {
        super.layout()
        hostingView?.frame = bounds
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
    }

    override func mouseDown(with event: NSEvent) {
        isHovering = true
        refreshRootView()
        onActivate?()
    }

    override func mouseUp(with event: NSEvent) {
        isHovering = false
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        isVisible = false
        hostingView?.removeFromSuperview()
        hostingView = nil
    }

    private func setupHostingView() {
        let root = GlowFrameView(cornerRadius: Layout.cornerRadius,
                                 baseLineWidth: Layout.strokeWidth,
                                 isHovering: isHovering)
        let hosting = NSHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        addSubview(hosting)
        hostingView = hosting
    }

    private func refreshRootView() {
        guard let hostingView else { return }
        hostingView.rootView = GlowFrameView(cornerRadius: Layout.cornerRadius,
                                             baseLineWidth: Layout.strokeWidth,
                                             isHovering: isHovering)
        hostingView.needsDisplay = true
    }
}

struct GlowFrameView: View {
    var cornerRadius: CGFloat
    var baseLineWidth: CGFloat
    var isHovering: Bool
    var palette: [Color]
    /// Slower animation cycle for validation glows (seconds between gradient shifts)
    var animationInterval: TimeInterval
    /// Longer transition for a slow, pulsing feel on validation
    var transitionDuration: TimeInterval

    @State private var gradientStops: [Gradient.Stop] = []
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher>

    init(cornerRadius: CGFloat, baseLineWidth: CGFloat, isHovering: Bool,
         palette: [Color] = GlowFrameView.completionPalette,
         animationInterval: TimeInterval = 0.45,
         transitionDuration: TimeInterval = 0.6) {
        self.cornerRadius = cornerRadius
        self.baseLineWidth = baseLineWidth
        self.isHovering = isHovering
        self.palette = palette
        self.animationInterval = animationInterval
        self.transitionDuration = transitionDuration
        self._gradientStops = State(initialValue: GlowFrameView.generateGradientStops(from: palette))
        self._timer = State(initialValue: Timer.publish(every: animationInterval, on: .main, in: .common).autoconnect())
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let gradient = AngularGradient(gradient: Gradient(stops: gradientStops), center: .center)

            ZStack {
                roundedStroke(gradient: gradient, lineWidth: baseLineWidth, blur: 0, opacity: isHovering ? 0.95 : 0.75)
                roundedStroke(gradient: gradient, lineWidth: baseLineWidth * 1.6, blur: 6, opacity: isHovering ? 0.55 : 0.4)
                roundedStroke(gradient: gradient, lineWidth: baseLineWidth * 2.3, blur: 13, opacity: isHovering ? 0.32 : 0.22)
            }
            .frame(width: size.width, height: size.height)
            .drawingGroup()
        }
        .allowsHitTesting(false)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: transitionDuration)) {
                gradientStops = GlowFrameView.generateGradientStops(from: palette)
            }
        }
    }

    private func roundedStroke(gradient: AngularGradient,
                               lineWidth: CGFloat,
                               blur: CGFloat,
                               opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(gradient, lineWidth: lineWidth)
            .blur(radius: blur)
            .opacity(opacity)
    }

    /// Default completion palette (violet/pink/periwinkle)
    static let completionPalette: [Color] = [
        ColorTokens.Glow.violet,
        ColorTokens.Glow.pink,
        ColorTokens.Glow.periwinkle,
        ColorTokens.Glow.coral,
        ColorTokens.Glow.peach,
        ColorTokens.Glow.lavender
    ]

    /// Validation error palette — deep reds and crimsons with warm accents.
    /// Slow-pulsing gradient that reads as "error" without being harsh.
    static let validationPalette: [Color] = [
        Color(red: 0.90, green: 0.20, blue: 0.20),  // crimson
        Color(red: 0.85, green: 0.15, blue: 0.25),  // deep red
        Color(red: 1.00, green: 0.35, blue: 0.30),  // warm red
        Color(red: 0.95, green: 0.25, blue: 0.20),  // scarlet
        Color(red: 1.00, green: 0.45, blue: 0.35),  // coral accent
        Color(red: 0.80, green: 0.18, blue: 0.22),  // dark crimson
    ]

    static func generateGradientStops(from palette: [Color] = completionPalette) -> [Gradient.Stop] {
        palette.map { color in
            Gradient.Stop(color: color, location: Double.random(in: 0...1))
        }.sorted(by: { $0.location < $1.location })
    }
}

#endif

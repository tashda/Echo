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

    @State private var gradientStops: [Gradient.Stop] = GlowFrameView.generateGradientStops()
    private let timer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

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
            withAnimation(.easeInOut(duration: 0.6)) {
                gradientStops = GlowFrameView.generateGradientStops()
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

    static func generateGradientStops() -> [Gradient.Stop] {
        let palette = [
            color(hex: "BC82F3"),
            color(hex: "F5B9EA"),
            color(hex: "8D9FFF"),
            color(hex: "FF6778"),
            color(hex: "FFBA71"),
            color(hex: "C686FF")
        ]

        return palette.map { color in
            Gradient.Stop(color: color, location: Double.random(in: 0...1))
        }.sorted(by: { $0.location < $1.location })
    }

    static func color(hex: String) -> Color {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")

        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)

        let r = Double((hexNumber & 0xff0000) >> 16) / 255.0
        let g = Double((hexNumber & 0x00ff00) >> 8) / 255.0
        let b = Double(hexNumber & 0x0000ff) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}

#endif

#if os(macOS)
import AppKit
import SwiftUI
import Combine

final class LineNumberRulerView: NSRulerView {
    weak var sqlTextView: SQLTextView?
    var highlightedLines: IndexSet = []
    var theme: SQLEditorTheme {
        didSet { needsDisplay = true }
    }

    private let paragraphStyle: NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        return style
    }()

    init(textView: SQLTextView, theme: SQLEditorTheme) {
        self.theme = theme
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.sqlTextView = textView
        self.clientView = textView
        self.ruleThickness = 40
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.height]
        setFrameSize(NSSize(width: ruleThickness, height: frame.size.height))
        setBoundsSize(NSSize(width: ruleThickness, height: bounds.size.height))

        // Observe text changes to update line numbers live
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    // Keep the ruler from stretching over the text view when AppKit resizes it.
    override func setFrameSize(_ newSize: NSSize) {
        let width = ruleThickness > 0 ? ruleThickness : newSize.width
        super.setFrameSize(NSSize(width: width, height: newSize.height))
    }

    override func setBoundsSize(_ newSize: NSSize) {
        let width = ruleThickness > 0 ? ruleThickness : newSize.width
        super.setBoundsSize(NSSize(width: width, height: newSize.height))
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        let gutterWidth = max(0, ruleThickness)
        let gutterRect = NSRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)

        // No background fill - transparent line numbers

        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: theme.surfaces.gutterText.nsColor,
            .paragraphStyle: paragraphStyle
        ]

        let glyphCount = layoutManager.numberOfGlyphs
        let nsString = textView.string as NSString

        if glyphCount == 0 || nsString.length == 0 {
            drawFallbackLine(with: attributes, in: gutterRect)
            return
        }

        layoutManager.ensureLayout(for: textContainer)

        var visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        if visibleGlyphRange.location == NSNotFound {
            visibleGlyphRange = NSRange(location: 0, length: glyphCount)
        }

        let initialGlyph = min(visibleGlyphRange.location, max(glyphCount - 1, 0))
        let maxGlyphIndex = min(NSMaxRange(visibleGlyphRange), glyphCount)
        if maxGlyphIndex <= initialGlyph {
            drawFallbackLine(with: attributes, in: gutterRect)
            return
        }

        var glyphIndex = initialGlyph
        while glyphIndex < maxGlyphIndex {
            var lineRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange, withoutAdditionalLayout: true)
            let yPosition = lineRect.minY + textView.textContainerInset.height - textView.visibleRect.origin.y

            let lineNumber = nsString.lineNumber(at: lineRange.location)
            let labelRect = NSRect(x: 0, y: yPosition + 2, width: gutterRect.width - 8, height: lineRect.height)
            ("\(lineNumber)" as NSString).draw(in: labelRect, withAttributes: attributes)

            glyphIndex = min(NSMaxRange(lineRange), maxGlyphIndex)
        }

        if layoutManager.extraLineFragmentTextContainer != nil {
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0 {
                let yPosition = extraRect.minY + textView.textContainerInset.height - textView.visibleRect.origin.y
                let labelRect = NSRect(x: 0, y: yPosition + 2, width: gutterRect.width - 8, height: extraRect.height)
                let lastLineNumber = nsString.lineNumber(at: nsString.length)
                ("\(lastLineNumber)" as NSString).draw(in: labelRect, withAttributes: attributes)
            }
        }

        // No divider – match Tahoe preview
    }

    private func drawFallbackLine(with attributes: [NSAttributedString.Key: Any], in rect: NSRect) {
        guard let textView = sqlTextView else {
            let labelRect = NSRect(x: 0, y: rect.minY + 4, width: rect.width - 8, height: rect.height)
            ("1" as NSString).draw(in: labelRect, withAttributes: attributes)
            return
        }

        let font = textView.theme.nsFont
        let lineHeight = max(CGFloat(16), font.ascender - font.descender + font.leading)
        let insetOrigin = textView.textContainerOrigin
        let visibleOffset = textView.visibleRect.origin.y
        let baseY = insetOrigin.y - visibleOffset
        let yPosition = max(rect.minY, baseY + 2)

        let labelRect = NSRect(
            x: 0,
            y: yPosition,
            width: rect.width - 8,
            height: lineHeight
        )
        ("1" as NSString).draw(in: labelRect, withAttributes: attributes)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard point.x <= ruleThickness else { return nil }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) { selectLine(event) }
    override func mouseDragged(with event: NSEvent) { selectLine(event) }

    private func selectLine(_ event: NSEvent) {
        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let glyphCount = layoutManager.numberOfGlyphs
        guard glyphCount > 0 else { return }

        let location = convert(event.locationInWindow, from: nil)
        let pointInTextView = convert(location, to: textView)
        var fraction: CGFloat = 0
        var glyphIndex = layoutManager.glyphIndex(for: pointInTextView, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        glyphIndex = min(max(glyphIndex, 0), glyphCount - 1)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let line = (textView.string as NSString).lineNumber(at: charIndex)
        textView.selectLineRange(line...line)
    }
}

final class CompletionAccessoryView: NSView {
    struct Layout {
        static let padding = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 7)
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

private struct GlowFrameView: View {
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

    private static func generateGradientStops() -> [Gradient.Stop] {
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

    private static func color(hex: String) -> Color {
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

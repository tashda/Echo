import SwiftUI
#if os(macOS)
import AppKit
import QuartzCore
#endif

private enum AutoScrollingMetrics {
    static let rowHeight: CGFloat = 16
    static let scrollThreshold: CGFloat = 6
}

#if os(macOS)
struct AutoScrollingText: View {
    let text: String
    let font: NSFont
    let isActive: Bool

    var body: some View {
        AutoScrollingTextRepresentable(text: text, font: font, isActive: isActive)
            .frame(height: AutoScrollingMetrics.rowHeight)
    }
}

private struct AutoScrollingTextRepresentable: NSViewRepresentable {
    let text: String
    let font: NSFont
    let isActive: Bool

    func makeNSView(context: Context) -> AutoScrollingTextContainerView {
        AutoScrollingTextContainerView()
    }

    func updateNSView(_ nsView: AutoScrollingTextContainerView, context: Context) {
        nsView.configure(text: text, font: font, isActive: isActive)
    }

    static func dismantleNSView(_ nsView: AutoScrollingTextContainerView, coordinator: ()) {
        nsView.teardown()
    }
}

private final class AutoScrollingTextContainerView: NSView {
    private let textLayer = CATextLayer()
    private let animationKey = "marquee"

    private var currentText: String = ""
    private var currentFont: NSFont = NSFont.systemFont(ofSize: 12)
    private var isActive: Bool = false
    private var currentOverflow: CGFloat = 0
    private var isAnimating = false
    private var currentColor: NSColor = .labelColor

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        setupTextLayer()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        updateLayoutAndAnimation()
    }

    func configure(text: String, font: NSFont, isActive: Bool) {
        var needsUpdate = false
        if currentText != text { currentText = text; textLayer.string = text; needsUpdate = true }
        if currentFont != font { currentFont = font; textLayer.font = font; textLayer.fontSize = font.pointSize; needsUpdate = true }
        if self.isActive != isActive { self.isActive = isActive; needsUpdate = true }

        let resolvedColor: NSColor = isActive ? .selectedMenuItemTextColor : .labelColor
        if currentColor != resolvedColor { currentColor = resolvedColor; textLayer.foregroundColor = resolvedColor.cgColor }

        if needsUpdate { needsLayout = true; layoutSubtreeIfNeeded() }
    }

    func teardown() { stopAnimation() }

    private func setupTextLayer() {
        guard let layer else { return }
        textLayer.alignmentMode = .left
        textLayer.truncationMode = .none
        textLayer.isWrapped = false
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        textLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        textLayer.position = CGPoint(x: 0, y: bounds.midY)
        textLayer.foregroundColor = currentColor.cgColor
        layer.addSublayer(textLayer)
    }

    private func updateLayoutAndAnimation() {
        guard bounds.width > 0 else { return }
        textLayer.position = CGPoint(x: 0, y: bounds.midY)
        let textSize = measuredTextSize(string: currentText, font: currentFont)
        textLayer.bounds = CGRect(origin: .zero, size: textSize)

        let overflow = max(0, textSize.width - bounds.width)
        guard isActive, overflow > AutoScrollingMetrics.scrollThreshold else {
            stopAnimation(); currentOverflow = 0; return
        }

        if isAnimating, abs(overflow - currentOverflow) < 0.5 { return }
        startAnimation(overflow: overflow)
    }

    private func measuredTextSize(string: String, font: NSFont) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let width = (string as NSString).size(withAttributes: attributes).width
        let rawHeight = font.ascender - font.descender + font.leading
        return CGSize(width: width, height: ceil(max(0, rawHeight)))
    }

    private func startAnimation(overflow: CGFloat) {
        stopAnimation()
        currentOverflow = overflow
        isAnimating = true
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = 0
        animation.toValue = -overflow
        animation.duration = max(Double(overflow / 36), 1.8)
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        textLayer.add(animation, forKey: animationKey)
    }

    private func stopAnimation() {
        guard isAnimating else { return }
        textLayer.removeAnimation(forKey: animationKey)
        textLayer.position = CGPoint(x: 0, y: bounds.midY)
        isAnimating = false
    }
}
#else
struct AutoScrollingText: View {
    let text: String
    let font: Font
    let isActive: Bool
    @State private var textWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let overflow = max(0, textWidth - availableWidth)
            let shouldAnimate = isActive && overflow > AutoScrollingMetrics.scrollThreshold
            Group {
                if shouldAnimate {
                    TimelineView(.animation) { timeline in
                        textLabel.offset(x: offset(for: timeline.date.timeIntervalSinceReferenceDate, overflow: overflow))
                    }
                } else { textLabel }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: AutoScrollingMetrics.rowHeight)
        .onChange(of: text) { _, _ in textWidth = 0 }
    }

    private var textLabel: some View {
        Text(text).font(font).lineLimit(1).background(widthReader)
    }

    private var widthReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { updateTextWidth(geo.size.width) }
                .onChange(of: geo.size.width) { _, newValue in updateTextWidth(newValue) }
        }
    }

    private func updateTextWidth(_ newValue: CGFloat) {
        let clamped = max(0, newValue)
        if abs(textWidth - clamped) > .leastNonzeroMagnitude { textWidth = clamped }
    }

    private func offset(for time: TimeInterval, overflow: CGFloat) -> CGFloat {
        guard overflow > AutoScrollingMetrics.scrollThreshold else { return 0 }
        let period = max(Double(overflow / 32), 1.6)
        let normalizedTime = (time.truncatingRemainder(dividingBy: period)) / period
        let progress = (sin(normalizedTime * .pi * 2) + 1) / 2
        return -CGFloat(progress) * overflow
    }
}
#endif

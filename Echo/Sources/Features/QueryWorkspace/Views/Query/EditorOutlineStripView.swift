#if os(macOS)
import AppKit
import EchoSense

/// QE5 (design board, 2026-09-30), a setting: a thin strip on the editor's right edge that
/// marks where each statement starts, where errors are (red) and which part is on screen
/// (accent). Clicking it jumps there. It replaces the scroll bar while it is on.
@MainActor
final class EditorOutlineStripView: NSView {
    weak var textView: SQLTextView?

    /// Positions from 0 (top) to 1 (bottom).
    var statementMarks: [CGFloat] = [] { didSet { needsDisplay = true } }
    var errorMarks: [CGFloat] = [] { didSet { needsDisplay = true } }
    var visibleSpan: ClosedRange<CGFloat> = 0...1 { didSet { if oldValue != visibleSpan { needsDisplay = true } } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let track = bounds
        let radius = track.width / 2
        NSColor.labelColor.withAlphaComponent(LayoutTokens.EditorOutline.trackOpacity).setFill()
        NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius).fill()

        let span = NSRect(x: track.minX, y: track.height * visibleSpan.lowerBound, width: track.width,
                          height: max(track.height * (visibleSpan.upperBound - visibleSpan.lowerBound), LayoutTokens.EditorOutline.markHeight * 2))
        NSColor.controlAccentColor.withAlphaComponent(LayoutTokens.EditorOutline.visibleOpacity).setFill()
        NSBezierPath(roundedRect: span, xRadius: radius, yRadius: radius).fill()

        NSColor.tertiaryLabelColor.setFill()
        statementMarks.forEach { mark($0).fill() }
        NSColor.systemRed.setFill()
        errorMarks.forEach { mark($0).fill() }
    }

    private func mark(_ position: CGFloat) -> NSBezierPath {
        let height = LayoutTokens.EditorOutline.markHeight
        let y = min(max(bounds.height * position - height / 2, 0), bounds.height - height)
        return NSBezierPath(roundedRect: NSRect(x: bounds.minX, y: y, width: bounds.width, height: height), xRadius: height / 2, yRadius: height / 2)
    }

    override func mouseDown(with event: NSEvent) { jump(to: event) }
    override func mouseDragged(with event: NSEvent) { jump(to: event) }

    private func jump(to event: NSEvent) {
        guard let textView, let scrollView = textView.enclosingScrollView, bounds.height > 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        let fraction = min(max(point.y / bounds.height, 0), 1)
        let visibleHeight = scrollView.contentView.bounds.height
        let y = max(textView.bounds.height * fraction - visibleHeight / 2, 0)
        scrollView.contentView.scroll(to: NSPoint(x: scrollView.contentView.bounds.minX, y: min(y, max(textView.bounds.height - visibleHeight, 0))))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// Recomputes the marks from the editor's statements, errors and scroll position.
    func refresh() {
        guard let textView else { return }
        let text = textView.string as NSString
        let totalLines = max(textView.lineNumber(at: text.length), 1)
        func position(ofLine line: Int) -> CGFloat { CGFloat(line - 1) / CGFloat(max(totalLines - 1, 1)) }
        statementMarks = textView.cachedStatements.map { position(ofLine: textView.lineNumber(at: $0.range.location)) }
        errorMarks = (textView.lineNumberRuler?.errorLines ?? []).map { position(ofLine: $0) }
        let documentHeight = max(textView.bounds.height, 1)
        let visible = textView.visibleRect
        visibleSpan = (visible.minY / documentHeight)...(min(visible.maxY / documentHeight, 1))
    }
}

extension LayoutTokens {
    /// QE5: the outline strip on the editor's right edge.
    enum EditorOutline {
        static let width: CGFloat = 6
        static let inset: CGFloat = SpacingTokens.xxs
        static let markHeight: CGFloat = 3
        static let trackOpacity: CGFloat = 0.05
        static let visibleOpacity: CGFloat = 0.28
    }
}
#endif

import AppKit

/// Round 27: an NSScrollView that puts the system's bars exactly where an option says, instead of
/// through scroller insets (which AppKit adds to the content insets), and reports the pointer.
final class LabRSScrollView: NSScrollView {
    /// The horizontal bar's place; nil leaves it where AppKit puts it.
    var horizontalFrame: LabRSBarFrame? { didSet { if oldValue != horizontalFrame { needsLayout = true; tile() } } }
    /// How far above the card's bottom edge the vertical bar ends.
    var verticalBottom: CGFloat = 0 { didSet { if oldValue != verticalBottom { tile() } } }
    /// Called with the pointer (top-left origin), or nil when it leaves.
    var onPointer: ((CGPoint?) -> Void)?
    /// Where the pointer makes the system bars show (V3, V4); nil leaves it to the system.
    var revealZone: ((CGPoint) -> Bool)?
    private var lastFlash = Date.distantPast
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    override func tile() {
        super.tile()
        if let frame = horizontalFrame, let bar = horizontalScroller {
            let thickness = NSScroller.scrollerWidth(for: bar.controlSize, scrollerStyle: scrollerStyle)
            bar.frame = NSRect(x: frame.left, y: bounds.height - frame.bottom - thickness,
                               width: max(bounds.width - frame.left - frame.right, 0), height: thickness)
        }
        if let bar = verticalScroller {
            var frame = bar.frame
            frame.size.height = max(bounds.height - verticalBottom - frame.minY, 0)
            bar.frame = frame
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        onPointer?(point)
        if let revealZone, revealZone(point), Date().timeIntervalSince(lastFlash) > 0.5 {
            lastFlash = Date()
            flashScrollers()
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onPointer?(nil)
    }
}


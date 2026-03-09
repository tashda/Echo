#if os(macOS)
import AppKit

final class HoverTableView: NSTableView {
    private var trackingArea: NSTrackingArea?
    private(set) var hoveredRow: Int = -1

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area); self.trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil); setHoveredRow(row(at: point))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHoveredRow(-1)
    }

    private func setHoveredRow(_ row: Int) {
        if row == hoveredRow { return }
        let prev = hoveredRow; hoveredRow = row
        if prev >= 0, let rv = rowView(atRow: prev, makeIfNecessary: false) as? HoverTableRowView { rv.isHovered = false }
        if hoveredRow >= 0, let rv = rowView(atRow: hoveredRow, makeIfNecessary: false) as? HoverTableRowView { rv.isHovered = true }
    }
}

final class HoverTableRowView: NSTableRowView {
    var isHovered = false { didSet { needsDisplay = true } }
    override func drawBackground(in dirtyRect: NSRect) {
        if isHovered && !isSelected { NSColor.controlAccentColor.withAlphaComponent(0.12).setFill(); dirtyRect.fill(); return }
        super.drawBackground(in: dirtyRect)
    }
}
#endif

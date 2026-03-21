#if os(macOS)
import AppKit

final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    private var cachedDrawingBounds: NSRect?
    private var cachedDrawingRect: NSRect = .zero
    private var cachedMeasuredBounds: NSRect?
    private var cachedMeasuredSize: NSSize = .zero

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        if let cachedBounds = cachedDrawingBounds, cachedBounds.equalTo(rect) {
            return cachedDrawingRect
        }
        var newRect = super.drawingRect(forBounds: rect)
        newRect.origin.x = rect.minX
        newRect.size.width = rect.width
        let textSize: NSSize
        if let measuredBounds = cachedMeasuredBounds, measuredBounds.equalTo(rect) {
            textSize = cachedMeasuredSize
        } else {
            let measured = cellSize(forBounds: rect)
            cachedMeasuredBounds = rect
            cachedMeasuredSize = measured
            textSize = measured
        }
        if newRect.height > textSize.height {
            let heightDelta = newRect.height - textSize.height
            newRect.origin.y += heightDelta / 2
            newRect.size.height = textSize.height
        }
        cachedDrawingBounds = rect
        cachedDrawingRect = newRect
        return newRect
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let adjusted = drawingRect(forBounds: rect)
        super.edit(withFrame: adjusted, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let adjusted = drawingRect(forBounds: rect)
        super.select(withFrame: adjusted, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    func invalidateCachedMetrics() {
        cachedDrawingBounds = nil
        cachedMeasuredBounds = nil
    }
}
#endif

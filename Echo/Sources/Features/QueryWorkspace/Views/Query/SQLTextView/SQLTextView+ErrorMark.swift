#if os(macOS)
import AppKit
import SwiftUI

/// Round 21 EM5 (accepted) and round 22 ED1: the last run's error as a red squiggle under the word
/// (a whole line when SQL Server names no object), the message in a bubble on hover, and a Fix
/// button when the server's hint or the table's columns name the right word (EH3).
extension SQLTextView {
    func showErrorMark() {
        errorMarkView?.removeFromSuperview()
        errorMarkView = nil
        guard let mark = errorMark, let layoutManager, let textContainer else { return }
        let length = (string as NSString).length
        guard mark.range.location != NSNotFound, mark.range.length > 0, NSMaxRange(mark.range) <= length else { return }
        let glyphs = layoutManager.glyphRange(forCharacterRange: mark.range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        guard rect.width > 0, rect.height > 0 else { return }
        let view = QueryErrorMarkView(mark: mark) { [weak self] fix in
            self?.applyErrorFix(fix, at: mark.range)
        }
        view.frame = rect
        addSubview(view)
        errorMarkView = view
    }

    /// EH3: replaces the marked word; undoable like typing. The edit clears the mark (EC3).
    func applyErrorFix(_ fix: QueryErrorMark.Fix, at range: NSRange) {
        guard NSMaxRange(range) <= (string as NSString).length,
              shouldChangeText(in: range, replacementString: fix.replacement) else { return }
        textStorage?.replaceCharacters(in: range, with: fix.replacement)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + (fix.replacement as NSString).length, length: 0))
        window?.makeFirstResponder(self)
    }
}

/// Draws the squiggle and shows the bubble while the pointer is over the marked text. Clicks pass
/// through to the editor.
final class QueryErrorMarkView: NSView {
    private let mark: QueryErrorMark
    private let onFix: (QueryErrorMark.Fix) -> Void
    private var popover: NSPopover?
    private var isHovering = false

    init(mark: QueryErrorMark, onFix: @escaping (QueryErrorMark.Fix) -> Void) {
        self.mark = mark
        self.onFix = onFix
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Error: \(mark.message)")
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath()
        let amplitude: CGFloat = 1.5
        let period: CGFloat = 4
        let y = bounds.maxY - amplitude - 0.5
        var x = bounds.minX
        path.move(to: NSPoint(x: x, y: y))
        var up = true
        while x < bounds.maxX {
            let next = min(x + period / 2, bounds.maxX)
            path.line(to: NSPoint(x: next, y: up ? y - amplitude : y + amplitude))
            x = next
            up.toggle()
        }
        path.lineWidth = 1
        NSColor.systemRed.setStroke()
        path.stroke()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        guard popover?.isShown != true else { return }
        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = true
        let bubble = QueryErrorBubble(mark: mark) { [weak self] fix in
            self?.popover?.close()
            self?.onFix(fix)
        }
        popover.contentViewController = NSHostingController(rootView: bubble)
        popover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
        self.popover = popover
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        // Leave time to move into the bubble and press Fix.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.isHovering, let popover = self.popover, popover.isShown else { return }
            if let frame = popover.contentViewController?.view.window?.frame, frame.contains(NSEvent.mouseLocation) {
                return
            }
            popover.close()
        }
    }

    override func removeFromSuperview() {
        popover?.close()
        super.removeFromSuperview()
    }
}

/// The bubble: the message, the hint or where inside a routine it failed, and Fix.
struct QueryErrorBubble: View {
    let mark: QueryErrorMark
    let onFix: (QueryErrorMark.Fix) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Label(mark.message, systemImage: "exclamationmark.octagon.fill")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Status.error)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = mark.detail {
                Text(detail)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let fix = mark.fix {
                Button(fix.title) { onFix(fix) }
                    .controlSize(.small)
            }
        }
        .textSelection(.enabled)
        .padding(SpacingTokens.xs)
        .frame(maxWidth: 360, alignment: .leading)
    }
}
#endif

#if os(macOS)
import AppKit
import SwiftUI

/// Round 28.6 (E10), in round 28.15's language: a mistake's mark, a strong red mark behind the word, the same for what
/// EchoSense finds while you type and what the server returns (SL0). Its bubble (BB3) opens while
/// the pointer is on the word or the caret is on its line (M3). Still: nothing moves (MO0).
/// Clicks pass through to the editor.
final class ErrorPillView: NSView {
    let content: ErrorBubbleContent
    /// The 1-based editor line the mark is on.
    let line: Int
    private let fill: NSColor
    private let corners: EditorMarkCorners
    private let onFix: (QueryErrorMark.Fix) -> Void
    private var popover: NSPopover?
    private var isHovering = false

    /// The caret is on this mark's line, so its bubble shows.
    var isCaretOnLine = false {
        didSet { if oldValue != isCaretOnLine { updateBubble() } }
    }

    init(content: ErrorBubbleContent, line: Int, fill: NSColor, corners: EditorMarkCorners,
         onFix: @escaping (QueryErrorMark.Fix) -> Void = { _ in }) {
        self.content = content
        self.line = line
        self.fill = fill
        self.corners = corners
        self.onFix = onFix
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Error: \(content.message)")
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        let radius = corners.radius(forHeight: bounds.height)
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateBubble()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        // Leave time to move into the bubble and press Fix.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.4))
            guard let self, !self.isHovering else { return }
            if let frame = self.popover?.contentViewController?.view.window?.frame, frame.contains(NSEvent.mouseLocation) { return }
            self.updateBubble()
        }
    }

    override func removeFromSuperview() {
        popover?.close()
        super.removeFromSuperview()
    }

    private func updateBubble() {
        let shouldShow = (isHovering || isCaretOnLine) && window != nil
        if shouldShow, popover?.isShown != true {
            let popover = NSPopover()
            popover.behavior = .semitransient
            popover.animates = true
            popover.contentViewController = NSHostingController(rootView: ErrorBubble(content: content) { [weak self] fix in
                self?.popover?.close()
                self?.onFix(fix)
            })
            popover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
            self.popover = popover
        } else if !shouldShow {
            popover?.close()
        }
    }
}
#endif

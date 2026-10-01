#if os(macOS)
import SwiftUI
import AppKit

final class ResultTableView: NSTableView {
    weak var selectionDelegate: QueryResultsTableView.Coordinator?
    private let cachedBackgroundColor = NSColor(ColorTokens.Background.tertiary)

    override var acceptsFirstResponder: Bool { true }

    private var hoverTrackingArea: NSTrackingArea?

    // MARK: - Hover (plan R4)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let hovered = row(at: convert(event.locationInWindow, from: nil))
        selectionDelegate?.setHoveredRow(hovered >= 0 ? hovered : nil, in: self)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        selectionDelegate?.setHoveredRow(nil, in: self)
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        // The row under a still pointer changes as the rows move.
        guard let window else { return }
        let hovered = row(at: convert(window.mouseLocationOutsideOfEventStream, from: nil))
        selectionDelegate?.setHoveredRow(hovered >= 0 ? hovered : nil, in: self)
    }

    override func highlightSelection(inClipRect clipRect: NSRect) {
        if selectionDelegate?.hasActiveCellSelection == true {
            return
        }
        super.highlightSelection(inClipRect: clipRect)
    }

    override func drawBackground(inClipRect clipRect: NSRect) {
        if usesAlternatingRowBackgroundColors {
            super.drawBackground(inClipRect: clipRect)
        } else {
            cachedBackgroundColor.setFill()
            clipRect.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Never call super.mouseDown — NSTableView (via NSControl) runs an
        // internal mouse-tracking loop that consumes all subsequent mouseDragged
        // and mouseUp events, preventing our overrides from being called.
        // Instead, handle selection programmatically via the coordinator.
        selectionDelegate?.handleMouseDown(event, in: self)
    }

    override func mouseDragged(with event: NSEvent) {
        selectionDelegate?.handleMouseDragged(event, in: self)
    }

    override func mouseUp(with event: NSEvent) {
        selectionDelegate?.handleMouseUp(event, in: self)
    }

    override func rightMouseDown(with event: NSEvent) {
        selectionDelegate?.handleRightMouseDown(event, in: self)
        let location = convert(event.locationInWindow, from: nil)
        let row = row(at: location)

        if selectionDelegate?.hasActiveCellSelection == true {
            deselectAll(nil)
            selectionHighlightStyle = .none
            if row >= 0, let rowView = rowView(atRow: row, makeIfNecessary: false) {
                rowView.needsDisplay = true
                rowView.displayIfNeeded()
            } else {
                needsDisplay = true
                displayIfNeeded()
            }
        }

        if let contextMenu = menu {
            NSMenu.popUpContextMenu(contextMenu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func keyDown(with event: NSEvent) {
        if selectionDelegate?.handleKeyDown(event, in: self) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        if selectionDelegate?.hasActiveCellSelection == true,
           let currentEvent = NSApp.currentEvent,
           currentEvent.type == .rightMouseDown
                || currentEvent.type == .otherMouseDown
                || currentEvent.type == .rightMouseDragged
                || (currentEvent.type == .leftMouseDown && currentEvent.modifierFlags.contains(.control)) {
            super.selectRowIndexes(IndexSet(), byExtendingSelection: false)
            return
        }
        super.selectRowIndexes(indexes, byExtendingSelection: extend)
    }

    override func selectAll(_ sender: Any?) {
        selectionDelegate?.selectAllCells(in: self)
    }

    @objc func copy(_ sender: Any?) {
        if selectionDelegate?.performMenuCopy(in: self) == true {
            return
        }
        NSApp.sendAction(#selector(NSTextView.copy(_:)), to: nil, from: self)
    }
}
#endif

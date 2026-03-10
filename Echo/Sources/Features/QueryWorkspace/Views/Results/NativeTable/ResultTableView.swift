#if os(macOS)
import SwiftUI
import AppKit

final class ResultTableView: NSTableView {
    weak var selectionDelegate: QueryResultsTableView.Coordinator?

    override var acceptsFirstResponder: Bool { true }

    override func highlightSelection(inClipRect clipRect: NSRect) {
        if selectionDelegate?.hasActiveCellSelection == true {
            return
        }
        super.highlightSelection(inClipRect: clipRect)
    }

    override func drawBackground(inClipRect clipRect: NSRect) {
        NSColor(ColorTokens.Background.tertiary).setFill()
        clipRect.fill()
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

    @objc func copy(_ sender: Any?) {
        if selectionDelegate?.performMenuCopy(in: self) == true {
            return
        }
        NSApp.sendAction(#selector(NSTextView.copy(_:)), to: nil, from: self)
    }
}
#endif

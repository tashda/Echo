#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {

    func beginColumnSelection(at column: Int, modifiers: NSEvent.ModifierFlags) {
        guard tableView != nil else { return }
        let columnCount = parent.query.displayedColumns.count
        guard columnCount > 0 else { return }

        let target = max(0, min(column, columnCount - 1))
        let anchor: Int
        if modifiers.contains(.shift), let stored = columnSelectionAnchor ?? selectionRegion?.start.column {
            anchor = max(0, min(stored, columnCount - 1))
        } else {
            anchor = target
        }
        columnSelectionAnchor = anchor
        applyColumnSelection(from: anchor, to: target)
    }

    func continueColumnSelection(to column: Int) {
        guard let tableView else { return }
        guard let anchor = columnSelectionAnchor else { return }
        let columnCount = parent.query.displayedColumns.count
        guard columnCount > 0 else { return }
        let clamped = max(0, min(column, columnCount - 1))
        applyColumnSelection(from: anchor, to: clamped)
        tableView.scrollColumnToVisible(clamped)
    }

    func endColumnSelection() {
        if selectionRegion == nil {
            columnSelectionAnchor = nil
        }
    }

    func endSelectionDrag() {
        isDraggingCellSelection = false
        stopAutoscroll()
    }
}
#endif

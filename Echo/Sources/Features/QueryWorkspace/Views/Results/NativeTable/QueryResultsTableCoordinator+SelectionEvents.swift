#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {

    func handleMouseDown(_ event: NSEvent, in tableView: NSTableView) {
        guard tableView.numberOfRows > 0 else { return }
        deactivateActiveSelectableField(in: tableView)
        contextMenuCell = nil
        tableView.window?.makeFirstResponder(tableView)
        lastDragLocationInWindow = event.locationInWindow
        stopAutoscroll()
        let point = tableView.convert(event.locationInWindow, from: nil)
        guard let cell = resolvedCell(at: point, in: tableView, allowOutOfBounds: false) else {
            clearColumnSelection(in: tableView)
            endSelectionDrag()
            tableView.deselectAll(nil)
            selectionAnchor = nil
            selectionFocus = nil
            selectionRegion = nil
            return
        }

        let clickCount = event.clickCount
        let extendSelection = event.modifierFlags.contains(.shift)
        let currentRegion = selectionRegion
        let anchorCell: QueryResultsTableView.SelectedCell

        if extendSelection, let existingAnchor = selectionAnchor {
            anchorCell = existingAnchor
        } else if let existingRegion = currentRegion, regionRepresentsEntireColumn(existingRegion, tableView: tableView) {
            anchorCell = cell
            setSelectionRegion(SelectedRegion(start: anchorCell, end: cell), tableView: tableView)
        } else {
            anchorCell = cell
            if currentRegion?.contains(cell) != true {
                setSelectionRegion(SelectedRegion(start: anchorCell, end: cell), tableView: tableView)
            }
        }

        if clickCount >= 2 {
            if let jsonSelection = makeJsonSelection(for: cell) {
                parent.onJsonEvent(.activate(jsonSelection))
                endSelectionDrag()
                return
            } else {
                focusCellEditor(at: cell, tableView: tableView)
                endSelectionDrag()
                return
            }
        }

        if extendSelection {
            setSelectionRegion(SelectedRegion(start: anchorCell, end: cell), tableView: tableView)
            selectionAnchor = anchorCell
        } else {
            setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView)
            selectionAnchor = cell
            parent.onClearColumnHighlight()
        }

        selectionFocus = cell
        isDraggingCellSelection = true
    }

    func handleRightMouseDown(_ event: NSEvent, in tableView: NSTableView) {
        guard tableView.numberOfRows > 0 else { return }
        deactivateActiveSelectableField(in: tableView)
        let point = tableView.convert(event.locationInWindow, from: nil)
        if point.y < 0 {
            contextMenuCell = nil
            return
        }

        guard let cell = resolvedCell(at: point, in: tableView, allowOutOfBounds: false) else {
            contextMenuCell = nil
            setSelectionRegion(nil, tableView: tableView)
            selectionAnchor = nil
            selectionFocus = nil
            return
        }

        if let region = selectionRegion, region.contains(cell) {
            contextMenuCell = cell
            selectionFocus = cell
            if selectionAnchor == nil {
                selectionAnchor = region.start
            }
            return
        }

        let region = SelectedRegion(start: cell, end: cell)
        setSelectionRegion(region, tableView: tableView)
        selectionAnchor = cell
        selectionFocus = cell
        parent.onClearColumnHighlight()
        contextMenuCell = cell
    }

    func handleMouseDragged(_ event: NSEvent, in tableView: NSTableView) {
        guard isDraggingCellSelection, let anchor = selectionAnchor else { return }
        let point = tableView.convert(event.locationInWindow, from: nil)
        guard let cell = resolvedCell(at: point, in: tableView, allowOutOfBounds: true) else { return }
        let region = SelectedRegion(start: anchor, end: cell)
        if selectionRegion != region {
            setSelectionRegion(region, tableView: tableView)
        }
        updateAutoscroll(for: event, tableView: tableView)
    }

    func handleMouseUp(_ event: NSEvent, in tableView: NSTableView) {
        endSelectionDrag()

        // Validate selection after drag ends — data may have changed mid-drag.
        if let region = selectionRegion {
            let maxRow = tableView.numberOfRows
            let maxColumn = parent.query.displayedColumns.count
            if maxRow == 0 || maxColumn == 0
                || region.normalizedRowRange.upperBound >= maxRow
                || region.normalizedColumnRange.upperBound >= maxColumn {
                setSelectionRegion(nil, tableView: tableView)
            }
        }
    }

    func handleKeyDown(_ event: NSEvent, in tableView: NSTableView) -> Bool {
        if let characters = event.charactersIgnoringModifiers?.lowercased(),
           event.modifierFlags.contains(.command) {
            switch characters {
            case "c":
                copySelection(includeHeaders: event.modifierFlags.contains(.shift))
                return true
            case "a":
                selectAllCells(in: tableView)
                return true
            default:
                break
            }
        }
        return handleNavigationKey(event, in: tableView)
    }

    func handleNavigationKey(_ event: NSEvent, in tableView: NSTableView) -> Bool {
        guard let specialKey = event.specialKey else { return false }
        let extend = event.modifierFlags.contains(.shift)

        switch specialKey {
        case .upArrow:
            moveSelection(rowDelta: -1, columnDelta: 0, extend: extend, tableView: tableView)
            return true
        case .downArrow:
            moveSelection(rowDelta: 1, columnDelta: 0, extend: extend, tableView: tableView)
            return true
        case .leftArrow:
            moveSelection(rowDelta: 0, columnDelta: -1, extend: extend, tableView: tableView)
            return true
        case .rightArrow, .tab:
            moveSelection(rowDelta: 0, columnDelta: 1, extend: extend, tableView: tableView)
            return true
        case .pageUp:
            moveSelection(rowDelta: -pageJumpAmount(for: tableView), columnDelta: 0, extend: extend, tableView: tableView)
            return true
        case .pageDown:
            moveSelection(rowDelta: pageJumpAmount(for: tableView), columnDelta: 0, extend: extend, tableView: tableView)
            return true
        case .home:
            moveSelection(rowDelta: 0, columnDelta: -Int.max, extend: extend, tableView: tableView)
            return true
        case .end:
            moveSelection(rowDelta: 0, columnDelta: Int.max, extend: extend, tableView: tableView)
            return true
        default:
            return false
        }
    }

    func pageJumpAmount(for tableView: NSTableView) -> Int {
        let visibleHeight = tableView.visibleRect.height
        let rowHeight = max(tableView.rowHeight, 1)
        return max(1, Int(visibleHeight / rowHeight) - 1)
    }

}
#endif

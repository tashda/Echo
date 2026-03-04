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

    func selectAllCells(in tableView: NSTableView) {
        let columnCount = tableView.tableColumns.count
        let rowCount = tableView.numberOfRows
        guard columnCount > 0, rowCount > 0 else {
            setSelectionRegion(nil, tableView: tableView)
            return
        }

        let topLeft = QueryResultsTableView.SelectedCell(row: 0, column: 0)
        let bottomRight = QueryResultsTableView.SelectedCell(row: rowCount - 1, column: columnCount - 1)
        setSelectionRegion(SelectedRegion(start: topLeft, end: bottomRight), tableView: tableView)
        selectionAnchor = topLeft
        selectionFocus = bottomRight
        endSelectionDrag()
        parent.onClearColumnHighlight()
    }

    func clearColumnSelection(in tableView: NSTableView) {
        setSelectionRegion(nil, tableView: tableView)
        tableView.highlightedTableColumn = nil
        parent.onClearColumnHighlight()
        deactivateActiveSelectableField(in: tableView)
        selectionAnchor = nil
        selectionFocus = nil
    }

    func moveSelection(rowDelta: Int, columnDelta: Int, extend: Bool, tableView: NSTableView) {
        guard tableView.numberOfRows > 0, tableView.tableColumns.count > 0 else { return }

        deactivateActiveSelectableField(in: tableView)
        ensureSelectionSeed(in: tableView)

        guard var focus = selectionFocus ?? selectionRegion?.end else { return }

        let maxRow = tableView.numberOfRows - 1
        let maxColumn = tableView.tableColumns.count - 1

        let targetRow: Int
        if rowDelta == Int.max {
            targetRow = maxRow
        } else if rowDelta == -Int.max {
            targetRow = 0
        } else {
            targetRow = max(0, min(maxRow, focus.row + rowDelta))
        }

        let targetColumn: Int
        if columnDelta == 0 {
            targetColumn = focus.column
        } else if columnDelta == Int.max {
            targetColumn = maxColumn
        } else if columnDelta == -Int.max {
            targetColumn = 0
        } else {
            targetColumn = max(0, min(maxColumn, focus.column + columnDelta))
        }

        focus = QueryResultsTableView.SelectedCell(row: targetRow, column: targetColumn)

        let anchor: QueryResultsTableView.SelectedCell
        if extend, let existingAnchor = selectionAnchor ?? selectionRegion?.start {
            anchor = existingAnchor
        } else {
            anchor = focus
        }

        let region = SelectedRegion(start: anchor, end: focus)
        setSelectionRegion(region, tableView: tableView)
        selectionAnchor = anchor
        selectionFocus = focus

        tableView.scrollRowToVisible(focus.row)
        tableView.scrollColumnToVisible(focus.column)
    }

    func ensureSelectionSeed(in tableView: NSTableView) {
        guard tableView.numberOfRows > 0, tableView.tableColumns.count > 0 else { return }
        if selectionRegion == nil {
            let defaultRow = tableView.clickedRow >= 0 ? tableView.clickedRow : (selectionFocus?.row ?? 0)
            let defaultColumn = tableView.clickedColumn >= 0 ? tableView.clickedColumn : (selectionFocus?.column ?? 0)
            let seed = QueryResultsTableView.SelectedCell(
                row: max(0, min(tableView.numberOfRows - 1, defaultRow)),
                column: max(0, min(tableView.tableColumns.count - 1, defaultColumn))
            )
            setSelectionRegion(SelectedRegion(start: seed, end: seed), tableView: tableView)
            selectionAnchor = seed
            selectionFocus = seed
        }
    }

    func focusCellEditor(at cell: QueryResultsTableView.SelectedCell, tableView: NSTableView) {
        guard let textField = tableView.view(atColumn: cell.column, row: cell.row, makeIfNecessary: false) as? NSTextField else {
            return
        }
        deactivateActiveSelectableField(in: tableView)
        textField.isSelectable = true
        activeSelectableField = textField
        tableView.window?.makeFirstResponder(textField)
        textField.selectText(nil)
    }

    // MARK: - Autoscroll

    func updateAutoscroll(for event: NSEvent, tableView: NSTableView) {
        guard event.type == .leftMouseDragged, NSEvent.pressedMouseButtons != 0 else {
            stopAutoscroll()
            return
        }
        lastDragLocationInWindow = event.locationInWindow
        guard let scrollView = tableView.enclosingScrollView else {
            stopAutoscroll()
            return
        }

        let visibleRect = tableView.visibleRect
        let location = tableView.convert(event.locationInWindow, from: nil)

        var velocity = CGPoint.zero
        let padding = autoscrollPadding

        if location.y < visibleRect.minY + padding {
            let distance = max((visibleRect.minY + padding) - location.y, 0)
            velocity.y = -autoscrollSpeed(for: distance, padding: padding)
        } else if location.y > visibleRect.maxY - padding {
            let distance = max(location.y - (visibleRect.maxY - padding), 0)
            velocity.y = autoscrollSpeed(for: distance, padding: padding)
        }

        if location.x < visibleRect.minX + padding {
            let distance = max((visibleRect.minX + padding) - location.x, 0)
            velocity.x = -autoscrollSpeed(for: distance, padding: padding)
        } else if location.x > visibleRect.maxX - padding {
            let distance = max(location.x - (visibleRect.maxX - padding), 0)
            velocity.x = autoscrollSpeed(for: distance, padding: padding)
        }

        autoscrollVelocity = velocity

        if velocity == .zero {
            stopAutoscroll()
        } else {
            let interval = preferredAutoscrollInterval(for: velocity)
            startAutoscroll(for: tableView, scrollView: scrollView, interval: interval)
        }
    }

    func autoscrollSpeed(for distance: CGFloat, padding: CGFloat) -> CGFloat {
        guard padding > 0 else { return 0 }
        let ratio = min(max(distance / padding, 0), 1)
        let adjusted = pow(ratio, 1.2)
        return adjusted * autoscrollMaxSpeed
    }

    func preferredAutoscrollInterval(for velocity: CGPoint) -> TimeInterval {
        let speed = max(abs(velocity.x), abs(velocity.y))
        if speed <= 0 {
            return defaultAutoscrollInterval * 2.5
        }
        let clamped = min(max(speed / autoscrollMaxSpeed, 0), 1)
        let scale = 1 + (1 - clamped) * 1.5
        return defaultAutoscrollInterval * scale
    }

    func startAutoscroll(for tableView: NSTableView, scrollView: NSScrollView, interval: TimeInterval) {
        if let timer = autoscrollTimer {
            if abs(timer.timeInterval - interval) <= 0.0005 {
                return
            }
            timer.invalidate()
            autoscrollTimer = nil
        }

        autoscrollTimerInterval = interval

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self, weak tableView] _ in
            Task { @MainActor [weak self, weak tableView] in
                guard let self, let tableView else {
                    self?.stopAutoscroll()
                    return
                }
                self.performAutoscrollStep(in: tableView)
            }
        }
        autoscrollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopAutoscroll() {
        autoscrollTimer?.invalidate()
        autoscrollTimer = nil
        autoscrollVelocity = .zero
        autoscrollTimerInterval = defaultAutoscrollInterval
    }

    func performAutoscrollStep(in tableView: NSTableView) {
        guard autoscrollVelocity != .zero,
              isDraggingCellSelection,
              NSEvent.pressedMouseButtons != 0,
              tableView.window?.isKeyWindow ?? false,
              let scrollView = tableView.enclosingScrollView else {
            stopAutoscroll()
            return
        }

        let currentOrigin = scrollView.contentView.bounds.origin
        var origin = currentOrigin
        let documentSize = tableView.bounds.size
        let clipSize = scrollView.contentView.bounds.size

        let maxOriginX = max(documentSize.width - clipSize.width, 0)
        let maxOriginY = max(documentSize.height - clipSize.height, 0)

        let dx = autoscrollVelocity.x * CGFloat(autoscrollTimerInterval)
        let dy = autoscrollVelocity.y * CGFloat(autoscrollTimerInterval)

        origin.x = min(max(origin.x + dx, 0), maxOriginX)
        origin.y = min(max(origin.y + dy, 0), maxOriginY)

        let movedX = abs(origin.x - currentOrigin.x)
        let movedY = abs(origin.y - currentOrigin.y)
        let didScroll = movedX > 0.1 || movedY > 0.1

        if origin.x <= 0 || origin.x >= maxOriginX { autoscrollVelocity.x = 0 }
        if origin.y <= 0 || origin.y >= maxOriginY { autoscrollVelocity.y = 0 }

        guard didScroll else {
            if autoscrollVelocity == .zero { stopAutoscroll() }
            return
        }

        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        processAutoscrollSelection(in: tableView)

        if autoscrollVelocity == .zero { stopAutoscroll() }
    }

    func processAutoscrollSelection(in tableView: NSTableView) {
        guard isDraggingCellSelection, let anchor = selectionAnchor else { return }
        let point = tableView.convert(lastDragLocationInWindow, from: nil)
        guard let cell = resolvedCell(at: point, in: tableView, allowOutOfBounds: true) else { return }
        let region = SelectedRegion(start: anchor, end: cell)
        if selectionRegion != region {
            setSelectionRegion(region, tableView: tableView)
        }
    }
}
#endif

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

    func applyColumnSelection(from start: Int, to end: Int) {
        guard let tableView else { return }
        let columnCount = parent.query.displayedColumns.count
        guard columnCount > 0 else { return }

        let clampedStart = max(0, min(start, columnCount - 1))
        let clampedEnd = max(0, min(end, columnCount - 1))
        let lower = min(clampedStart, clampedEnd)
        let upper = max(clampedStart, clampedEnd)

        let maxRow = tableView.numberOfRows - 1
        if maxRow < 0 {
            tableView.scrollColumnToVisible(lower)
            tableView.scrollColumnToVisible(upper)
            return
        }

        let top = QueryResultsTableView.SelectedCell(row: 0, column: lower)
        let bottom = QueryResultsTableView.SelectedCell(row: maxRow, column: upper)
        setSelectionRegion(SelectedRegion(start: top, end: bottom), tableView: tableView)
        selectionAnchor = top
        selectionFocus = bottom
        tableView.scrollColumnToVisible(lower)
        tableView.scrollColumnToVisible(upper)
    }

    func setSelectionRegion(_ region: SelectedRegion?, tableView: NSTableView?) {
        let previous = selectionRegion
        selectionRegion = region
        selectionAnchor = region?.start
        selectionFocus = region?.end

        guard let tableView else { return }

        let desiredStyle: NSTableView.SelectionHighlightStyle = region != nil ? .none : .regular
        if tableView.selectionHighlightStyle != desiredStyle {
            tableView.selectionHighlightStyle = desiredStyle
            lastSelectionHighlightStyle = desiredStyle
        }

        if region != nil {
            tableView.deselectAll(nil)
        } else {
            endSelectionDrag()
            deactivateActiveSelectableField(in: tableView)
        }

        refreshSelectionTransition(from: previous, to: region, tableView: tableView)

        tableView.highlightedTableColumn = nil
        if let region,
           regionRepresentsEntireColumn(region, tableView: tableView),
           region.start.column >= 0,
           region.start.column < tableView.tableColumns.count {
            tableView.highlightedTableColumn = tableView.tableColumns[region.start.column]
        } else {
            parent.onClearColumnHighlight()
        }

        refreshVisibleRowBackgrounds(tableView)
        notifyJsonSelection(region)
        notifyForeignKeySelection(region)
    }

    func endSelectionDrag() {
        let wasDragging = isDraggingCellSelection
        isDraggingCellSelection = false
        stopAutoscroll()
        if wasDragging {
            flushDeferredReloads()
        }
    }

    func flushDeferredReloads() {
        guard !isDraggingCellSelection else { return }
        let items = pendingReloadWorkItems
        pendingReloadWorkItems.removeAll()
        for item in items {
            DispatchQueue.main.async(execute: item)
        }
    }

    func enqueueReloadWorkItem(_ item: DispatchWorkItem?) {
        guard let item else { return }
        if isDraggingCellSelection {
            pendingReloadWorkItems.append(item)
        } else {
            DispatchQueue.main.async(execute: item)
        }
    }

    func regionRepresentsEntireColumn(_ region: SelectedRegion, tableView: NSTableView) -> Bool {
        guard region.start.column == region.end.column else { return false }
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return false }
        return region.normalizedRowRange.lowerBound <= 0 && region.normalizedRowRange.upperBound >= rowCount - 1
    }

    func deactivateActiveSelectableField(in tableView: NSTableView?) {
        guard let field = activeSelectableField else { return }
        if let tableView, let window = tableView.window, let editor = window.firstResponder as? NSTextView, editor.delegate as? NSTextField === field {
            window.makeFirstResponder(tableView)
        }
        field.isSelectable = false
        activeSelectableField = nil
    }

    func refreshSelectionTransition(from previous: SelectedRegion?, to current: SelectedRegion?, tableView: NSTableView) {
        guard tableView.numberOfRows > 0,
              tableView.tableColumns.count > 0,
              previous != nil || current != nil else { return }

        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.length > 0 else { return }

        let maxRowIndex = tableView.numberOfRows - 1
        let visibleLower = max(0, visibleRows.location)
        let visibleUpper = min(maxRowIndex, visibleLower + max(visibleRows.length - 1, 0))

        let previousRows = rowBounds(for: previous, tableView: tableView)
        let currentRows = rowBounds(for: current, tableView: tableView)
        let rowsToAdd = rangeDifference(currentRows, subtracting: previousRows)
        let rowsToRemove = rangeDifference(previousRows, subtracting: currentRows)
        let overlappingRows = rangeIntersection(previousRows, currentRows)

        let maxColumnIndex = tableView.tableColumns.count - 1
        let previousColumns = columnBounds(for: previous, maxColumn: maxColumnIndex)
        let currentColumns = columnBounds(for: current, maxColumn: maxColumnIndex)

        let rowsRequiringRedraw = collectBoundaryRows(previous: previousRows, current: currentRows)

        applySelectionChange(
            rows: rowsToAdd,
            visibleLower: visibleLower,
            visibleUpper: visibleUpper,
            columnsProvider: { _ in currentColumns },
            isSelected: true,
            tableView: tableView
        )

        applySelectionChange(
            rows: rowsToRemove,
            visibleLower: visibleLower,
            visibleUpper: visibleUpper,
            columnsProvider: { _ in previousColumns },
            isSelected: false,
            tableView: tableView
        )

        if let overlap = overlappingRows,
           let clamped = clampRange(overlap, lower: visibleLower, upper: visibleUpper) {
            let columnAdd = rangeDifference(currentColumns, subtracting: previousColumns)
            let columnRemove = rangeDifference(previousColumns, subtracting: currentColumns)
            if !columnAdd.isEmpty || !columnRemove.isEmpty {
                for row in clamped.lowerBound...clamped.upperBound {
                    for addRange in columnAdd {
                        applySelectionChange(
                            rows: [row...row],
                            visibleLower: visibleLower,
                            visibleUpper: visibleUpper,
                            columnsProvider: { _ in addRange },
                            isSelected: true,
                            tableView: tableView
                        )
                    }
                    for removeRange in columnRemove {
                        applySelectionChange(
                            rows: [row...row],
                            visibleLower: visibleLower,
                            visibleUpper: visibleUpper,
                            columnsProvider: { _ in removeRange },
                            isSelected: false,
                            tableView: tableView
                        )
                    }
                }
            }
        }

        for row in rowsRequiringRedraw {
            guard row >= visibleLower, row <= visibleUpper,
                  let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ResultTableRowView else { continue }
            rowView.needsDisplay = true
            rowView.displayIfNeeded()
        }
    }

    func applySelectionChange(rows: [ClosedRange<Int>],
                              visibleLower: Int,
                              visibleUpper: Int,
                              columnsProvider: (Int) -> ClosedRange<Int>?,
                              isSelected: Bool,
                              tableView: NSTableView) {
        guard !rows.isEmpty else { return }
        let maxColumnIndex = tableView.tableColumns.count - 1
        for range in rows {
            guard let clampedRows = clampRange(range, lower: visibleLower, upper: visibleUpper) else { continue }
            for row in clampedRows.lowerBound...clampedRows.upperBound {
                guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) else { continue }
                let resultRowView = rowView as? ResultTableRowView
                resultRowView?.needsDisplay = true
                guard let columnRange = columnsProvider(row),
                      let clampedColumns = clampRange(columnRange, lower: 0, upper: maxColumnIndex) else {
                    resultRowView?.displayIfNeeded()
                    continue
                }
                for column in clampedColumns.lowerBound...clampedColumns.upperBound {
                    guard let cellView = rowView.view(atColumn: column) as? ResultTableDataCellView else { continue }
                    cellView.updateSelectionState(isSelected: isSelected)
                }
                resultRowView?.displayIfNeeded()
            }
        }
    }

    func collectBoundaryRows(previous: ClosedRange<Int>?, current: ClosedRange<Int>?) -> Set<Int> {
        var rows: Set<Int> = []
        if let previous {
            rows.insert(previous.lowerBound)
            rows.insert(previous.upperBound)
        }
        if let current {
            rows.insert(current.lowerBound)
            rows.insert(current.upperBound)
        }
        return rows
    }

    func rowBounds(for region: SelectedRegion?, tableView: NSTableView) -> ClosedRange<Int>? {
        guard let region else { return nil }
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return nil }
        let maxRowIndex = rowCount - 1
        let lower = max(region.normalizedRowRange.lowerBound, 0)
        let upper = min(region.normalizedRowRange.upperBound, maxRowIndex)
        return lower <= upper ? lower...upper : nil
    }

    func columnBounds(for region: SelectedRegion?, maxColumn: Int) -> ClosedRange<Int>? {
        guard let region, maxColumn >= 0 else { return nil }
        let lower = max(0, min(region.normalizedColumnRange.lowerBound, maxColumn))
        let upper = max(0, min(region.normalizedColumnRange.upperBound, maxColumn))
        return lower <= upper ? lower...upper : nil
    }

    func clampRange(_ range: ClosedRange<Int>, lower: Int, upper: Int) -> ClosedRange<Int>? {
        let clampedLower = max(range.lowerBound, lower)
        let clampedUpper = min(range.upperBound, upper)
        return clampedLower <= clampedUpper ? clampedLower...clampedUpper : nil
    }

    func clampRange(_ range: ClosedRange<Int>?, lower: Int, upper: Int) -> ClosedRange<Int>? {
        guard let range else { return nil }
        return clampRange(range, lower: lower, upper: upper)
    }

    func rangeDifference(_ source: ClosedRange<Int>?, subtracting other: ClosedRange<Int>?) -> [ClosedRange<Int>] {
        guard let source else { return [] }
        guard let other else { return [source] }
        if source.upperBound < other.lowerBound || source.lowerBound > other.upperBound {
            return [source]
        }
        var results: [ClosedRange<Int>] = []
        if source.lowerBound < other.lowerBound {
            results.append(source.lowerBound...min(other.lowerBound - 1, source.upperBound))
        }
        if source.upperBound > other.upperBound {
            results.append(max(other.upperBound + 1, source.lowerBound)...source.upperBound)
        }
        return results
    }

    func rangeIntersection(_ lhs: ClosedRange<Int>?, _ rhs: ClosedRange<Int>?) -> ClosedRange<Int>? {
        guard let lhs, let rhs else { return nil }
        let lower = max(lhs.lowerBound, rhs.lowerBound)
        let upper = min(lhs.upperBound, rhs.upperBound)
        return lower <= upper ? lower...upper : nil
    }

    func selectionRenderInfo(forRow row: Int, rowView: NSTableRowView, tableView: NSTableView) -> ResultTableRowView.SelectionRenderInfo? {
        guard let region = selectionRegion, region.containsRow(row) else { return nil }
        let maxColumn = tableView.tableColumns.count - 1
        guard maxColumn >= 0 else { return nil }

        let lowerColumn = max(0, min(region.normalizedColumnRange.lowerBound, maxColumn))
        let upperColumn = max(0, min(region.normalizedColumnRange.upperBound, maxColumn))
        guard upperColumn >= lowerColumn else { return nil }

        let leftEdge = tableView.rect(ofColumn: lowerColumn).minX
        let rightEdge = tableView.rect(ofColumn: upperColumn).maxX

        let isTop = row == region.normalizedRowRange.lowerBound
        let isBottom = row == region.normalizedRowRange.upperBound

        var rect = NSRect(x: leftEdge, y: tableView.rect(ofRow: row).minY, width: rightEdge - leftEdge, height: tableView.rowHeight)
        rect = rect.insetBy(dx: 1.5, dy: 0)

        var converted = rowView.convert(rect, from: tableView)

        let topInset: CGFloat = isTop ? 2 : 0
        let bottomInset: CGFloat = isBottom ? 2 : 0

        if rowView.isFlipped {
            converted.origin.y += topInset
            converted.size.height -= (topInset + bottomInset)
        } else {
            converted.origin.y += bottomInset
            converted.size.height -= (topInset + bottomInset)
        }

        converted.size.height = max(converted.size.height, 0)

        let topRadiusRaw: CGFloat = isTop ? 6 : 0
        let bottomRadiusRaw: CGFloat = isBottom ? 6 : 0
        let (topRadius, bottomRadius): (CGFloat, CGFloat)
        if rowView.isFlipped {
            topRadius = bottomRadiusRaw
            bottomRadius = topRadiusRaw
        } else {
            topRadius = topRadiusRaw
            bottomRadius = bottomRadiusRaw
        }

        return ResultTableRowView.SelectionRenderInfo(rect: converted, topCornerRadius: topRadius, bottomCornerRadius: bottomRadius)
    }

    var hasActiveCellSelection: Bool { selectionRegion != nil }

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

    func resolvedCell(forRow row: Int, column: Int, tableView: NSTableView) -> QueryResultsTableView.SelectedCell? {
        guard row >= 0, row < tableView.numberOfRows else { return nil }
        guard column >= 0, column < tableView.tableColumns.count else { return nil }
        guard column < parent.query.displayedColumns.count else { return nil }
        return QueryResultsTableView.SelectedCell(row: row, column: column)
    }

    func resolvedCell(at point: NSPoint, in tableView: NSTableView, allowOutOfBounds: Bool) -> QueryResultsTableView.SelectedCell? {
        var row = tableView.row(at: point)
        var column = tableView.column(at: point)

        if allowOutOfBounds {
            row = clampRow(row, point: point, tableView: tableView)
            column = clampColumn(column, point: point, tableView: tableView)
        }

        return resolvedCell(forRow: row, column: column, tableView: tableView)
    }

    func clampRow(_ row: Int, point: NSPoint, tableView: NSTableView) -> Int {
        if row >= 0 { return row }
        let maxRow = tableView.numberOfRows - 1
        guard maxRow >= 0 else { return -1 }

        if point.y < 0 { return 0 }

        let lastRowRect = tableView.rect(ofRow: maxRow)
        if point.y > lastRowRect.maxY { return maxRow }

        let clampedPoint = NSPoint(x: point.x, y: min(max(point.y, 0), lastRowRect.maxY - 1))
        let fallback = tableView.row(at: clampedPoint)
        if fallback >= 0 { return fallback }

        let approximate = Int(clampedPoint.y / max(tableView.rowHeight, 1))
        return max(0, min(maxRow, approximate))
    }

    func clampColumn(_ column: Int, point: NSPoint, tableView: NSTableView) -> Int {
        let maxIndex = tableView.tableColumns.count - 1
        if maxIndex < 0 { return -1 }
        if column >= 0 && column <= maxIndex { return column }

        if point.x < 0 { return 0 }

        let lastColumnRect = tableView.rect(ofColumn: maxIndex)
        if point.x > lastColumnRect.maxX { return maxIndex }

        let clampedX = min(max(point.x, 0), lastColumnRect.maxX - 1)
        let probePoint = NSPoint(x: clampedX, y: point.y)
        let fallback = tableView.column(at: probePoint)
        if fallback >= 0 { return min(fallback, maxIndex) }

        var cumulativeWidth: CGFloat = 0
        for (index, column) in tableView.tableColumns.enumerated() {
            cumulativeWidth += column.width
            if clampedX < cumulativeWidth { return index }
        }

        return maxIndex
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

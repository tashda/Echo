#if os(macOS)
import EchoSense
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {

    func applyColumnSelection(from start: Int, to end: Int) {
        guard let tableView else { return }
        let columnCount = queryState.displayedColumns.count
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
        updateAccentRowNumbers(in: tableView)
        updateSelectionSummary(for: region)

        let desiredStyle: NSTableView.SelectionHighlightStyle = region != nil ? .none : .regular
        if tableView.selectionHighlightStyle != desiredStyle {
            tableView.selectionHighlightStyle = desiredStyle
            lastSelectionHighlightStyle = desiredStyle
        }

        if region != nil {
            if !tableView.selectedRowIndexes.isEmpty { tableView.deselectAll(nil) }
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
            notifyClearColumnHighlight()
        }

        refreshVisibleRowBackgrounds(tableView)
        notifyJsonSelection(region)
        notifyForeignKeySelection(region)
        syncPersistedSelection()
    }

    func refreshSelectionTransition(from old: SelectedRegion?, to new: SelectedRegion?, tableView: NSTableView) {
        // Determine the rows that need visual updates (union of old, new, and additional regions).
        var ranges: [ClosedRange<Int>] = []
        if let o = old { ranges.append(o.normalizedRowRange) }
        if let n = new { ranges.append(n.normalizedRowRange) }
        for r in additionalRegions { ranges.append(r.normalizedRowRange) }
        guard !ranges.isEmpty else { return }

        let minRow = ranges.map(\.lowerBound).min()!
        let maxRow = ranges.map(\.upperBound).max()!

        // Only touch visible rows to keep drag smooth.
        let visible = tableView.rows(in: tableView.visibleRect)
        let visLower = visible.location
        let visUpper = visible.location + visible.length - 1
        let lower = max(minRow, visLower)
        let upper = min(maxRow, visUpper)
        guard lower <= upper else { return }

        for row in lower...upper {
            tableView.rowView(atRow: row, makeIfNecessary: false)?.needsDisplay = true
        }
    }

    func rangeDifference(_ source: ClosedRange<Int>, _ other: ClosedRange<Int>?) -> [ClosedRange<Int>] {
        guard let other else { return [source] }
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

    func selectionRenderInfos(forRow row: Int, rowView: NSTableRowView, tableView: NSTableView) -> [ResultTableRowView.SelectionRenderInfo] {
        var allRegions = additionalRegions
        if let active = selectionRegion { allRegions.append(active) }
        guard !allRegions.isEmpty else { return [] }

        let maxColumn = tableView.tableColumns.count - 1
        guard maxColumn >= 0 else { return [] }

        var results: [ResultTableRowView.SelectionRenderInfo] = []
        for region in allRegions {
            guard region.containsRow(row) else { continue }
            if let info = renderInfo(for: region, row: row, rowView: rowView, tableView: tableView, maxColumn: maxColumn) {
                results.append(info)
            }
        }
        return results
    }

    private func renderInfo(for region: SelectedRegion, row: Int, rowView: NSTableRowView, tableView: NSTableView, maxColumn: Int) -> ResultTableRowView.SelectionRenderInfo? {
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

        var info = ResultTableRowView.SelectionRenderInfo(rect: converted, topCornerRadius: topRadius, bottomCornerRadius: bottomRadius)
        // The active cell (where the selection started) gets a stronger ring, when the range has
        // more than one cell.
        if region == selectionRegion, region.start.row == row, region.start != region.end,
           region.start.column >= 0, region.start.column <= maxColumn {
            let cellRect = NSRect(
                x: tableView.rect(ofColumn: region.start.column).minX,
                y: tableView.rect(ofRow: row).minY,
                width: tableView.rect(ofColumn: region.start.column).width,
                height: tableView.rowHeight
            )
            info.activeCellRect = rowView.convert(cellRect, from: tableView).insetBy(dx: 1.5, dy: 1)
        }
        return info
    }

    var hasActiveCellSelection: Bool { selectionRegion != nil || !additionalRegions.isEmpty }

    /// Selects the entire row (all columns) when the user clicks a row number.
    func beginRowSelection(at row: Int) {
        guard let tableView else { return }
        let columnCount = queryState.displayedColumns.count
        guard columnCount > 0, row >= 0, row < tableView.numberOfRows else { return }
        isDraggingCellSelection = false
        isDraggingRowSelection = true
        let start = QueryResultsTableView.SelectedCell(row: row, column: 0)
        let end = QueryResultsTableView.SelectedCell(row: row, column: columnCount - 1)
        setSelectionRegion(SelectedRegion(start: start, end: end), tableView: tableView)
    }

    /// Extends the current row selection to include the given row (for drag on row numbers).
    func extendRowSelection(to row: Int) {
        guard let tableView else { return }
        let columnCount = queryState.displayedColumns.count
        guard columnCount > 0, row >= 0, row < tableView.numberOfRows else { return }
        let anchorRow = selectionAnchor?.row ?? row
        let startRow = min(anchorRow, row)
        let endRow = max(anchorRow, row)
        let start = QueryResultsTableView.SelectedCell(row: startRow, column: 0)
        let end = QueryResultsTableView.SelectedCell(row: endRow, column: columnCount - 1)
        let region = SelectedRegion(start: start, end: end)
        let previous = selectionRegion
        selectionRegion = region
        selectionFocus = end
        // Keep anchor from original click
        if selectionAnchor == nil {
            selectionAnchor = start
        }
        refreshSelectionTransition(from: previous, to: region, tableView: tableView)
        refreshVisibleRowBackgrounds(tableView)
        syncPersistedSelection()
    }

    func resolvedRowForDragSelection(at point: NSPoint, in tableView: NSTableView) -> Int? {
        guard tableView.numberOfRows > 0 else { return nil }
        let row = tableView.row(at: point)
        if row >= 0 {
            return min(row, tableView.numberOfRows - 1)
        }
        if point.y < tableView.visibleRect.minY {
            return 0
        }
        if point.y > tableView.visibleRect.maxY {
            return tableView.numberOfRows - 1
        }
        return nil
    }
}

extension QueryResultsTableView.Coordinator {
    /// The row under the pointer (plan R4): its row view tints and its number turns accent.
    func setHoveredRow(_ row: Int?, in tableView: NSTableView) {
        guard row != hoveredRow else { return }
        if let previous = hoveredRow, previous < tableView.numberOfRows {
            (tableView.rowView(atRow: previous, makeIfNecessary: false) as? ResultTableRowView)?.isHovered = false
        }
        if let row, row < tableView.numberOfRows {
            (tableView.rowView(atRow: row, makeIfNecessary: false) as? ResultTableRowView)?.isHovered = true
        }
        hoveredRow = row
        updateAccentRowNumbers(in: tableView)
    }

    /// The selected cells' figures for the footer's pill and its popover (round 41.2); huge
    /// selections are only counted.
    func updateSelectionSummary(for region: SelectedRegion?) {
        guard let region else {
            if queryState.gridSelectionSummary != nil { queryState.gridSelectionSummary = nil }
            return
        }
        let rows = region.normalizedRowRange
        let columns = region.normalizedColumnRange
        guard rows.lowerBound >= 0, columns.lowerBound >= 0 else { return }
        let cellCount = rows.count * columns.count
        var values: [String?] = []
        if cellCount <= GridSelectionSummary.maximumSummedCells {
            values.reserveCapacity(cellCount)
            for row in rows {
                let source = resolvedRowIndex(for: row)
                for column in columns {
                    values.append(source >= 0 ? queryState.valueForDisplay(row: source, column: column) : nil)
                }
            }
        }
        let columnsShown = queryState.displayedColumns
        let columnName = columns.count == 1 && columnsShown.indices.contains(columns.lowerBound) ? columnsShown[columns.lowerBound].name : nil
        let summary = GridSelectionSummary.summarize(values, cellCount: cellCount, columnName: columnName)
        if queryState.gridSelectionSummary != summary { queryState.gridSelectionSummary = summary }
    }

    /// Accent row numbers for the selected rows and the hovered row (plans R3, R4).
    func updateAccentRowNumbers(in tableView: NSTableView) {
        var rows = IndexSet()
        for region in additionalRegions + [selectionRegion].compactMap({ $0 }) {
            let range = region.normalizedRowRange
            if range.lowerBound >= 0 { rows.insert(integersIn: range.lowerBound...range.upperBound) }
        }
        rows.formUnion(tableView.selectedRowIndexes)
        let selected = rows
        if let hoveredRow { rows.insert(hoveredRow) }
        (tableView.enclosingScrollView?.superview as? ResultTableContainerView)?.setAccentRows(rows, selected: selected)
    }
}
#endif

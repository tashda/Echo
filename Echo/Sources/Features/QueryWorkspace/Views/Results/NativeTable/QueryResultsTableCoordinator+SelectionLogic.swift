#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {

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

    func refreshSelectionTransition(from old: SelectedRegion?, to new: SelectedRegion?, tableView: NSTableView) {
        guard let oldRows = old?.normalizedRowRange, let newRows = new?.normalizedRowRange else {
            tableView.reloadData()
            return
        }

        let combined = min(oldRows.lowerBound, newRows.lowerBound)...max(oldRows.upperBound, newRows.upperBound)
        let diff = rangeDifference(combined, rangeIntersection(oldRows, newRows))
        for range in diff {
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: range))
        }

        if old?.normalizedColumnRange != new?.normalizedColumnRange {
            tableView.reloadData()
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
}
#endif

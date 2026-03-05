#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {
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

    func regionRepresentsEntireColumn(_ region: SelectedRegion, tableView: NSTableView) -> Bool {
        let rows = region.normalizedRowRange
        return rows.lowerBound == 0 && rows.upperBound == (tableView.numberOfRows - 1) && rows.count > 0
    }
}
#endif

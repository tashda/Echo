#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {
    
    func reloadColumns() -> Bool {
        guard let tableView else { return false }
        let columnIDs = parent.query.displayedColumns.map(\.id)
        let columnsChanged = tableView.tableColumns.count != columnIDs.count || columnIDs != cachedColumnIDs
        var headerNeedsRefresh = false

        if columnsChanged {
            while tableView.tableColumns.count > 0 { tableView.removeTableColumn(tableView.tableColumns[0]) }
            addDataColumns(to: tableView)
            headerNeedsRefresh = true
        } else {
            for (offset, column) in parent.query.displayedColumns.enumerated() {
                let tableColumn = tableView.tableColumns[offset]
                if tableColumn.title != column.name { tableColumn.title = column.name; headerNeedsRefresh = true }
                let minWidth = defaultWidth(for: column)
                if abs(tableColumn.minWidth - minWidth) > 1 {
                    tableColumn.minWidth = minWidth
                    if tableColumn.width < minWidth { tableColumn.width = minWidth }
                }
                tableColumn.headerCell.alignment = .left
            }
        }
        tableView.headerView?.needsDisplay = true
        if headerNeedsRefresh { applyHeaderStyle(to: tableView) }
        cachedColumnKinds = parent.query.displayedColumns.map { ResultGridValueClassifier.kind(for: $0, value: "") }
        cachedColumnIDs = columnIDs
        return columnsChanged
    }

    func addDataColumns(to tableView: NSTableView) {
        for column in parent.query.displayedColumns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("data-\(column.id)"))
            tableColumn.title = column.name
            tableColumn.minWidth = defaultWidth(for: column)
            tableColumn.width = tableColumn.minWidth
            tableColumn.isEditable = false
            tableColumn.resizingMask = [.userResizingMask]
            if !(tableColumn.headerCell is ResultTableHeaderCell) { tableColumn.headerCell = ResultTableHeaderCell(textCell: column.name) }
            tableColumn.headerCell.controlSize = .regular; tableColumn.headerCell.alignment = .left
            tableColumn.headerCell.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            tableView.addTableColumn(tableColumn)
        }
    }

    func defaultWidth(for column: ColumnInfo) -> CGFloat {
        let type = column.dataType.lowercased()
        if type.contains("bool") { return 80 }
        if type.contains("int") || type.contains("numeric") || type.contains("decimal") || type.contains("float") || type.contains("double") || type.contains("money") { return 120 }
        if type.contains("date") || type.contains("time") { return 160 }
        return 200
    }

    func headerContentWidth(for column: NSTableColumn, in tableView: NSTableView) -> CGFloat {
        let baseString: NSString; let attributes: [NSAttributedString.Key: Any]
        if column.headerCell.attributedStringValue.length > 0 {
            baseString = column.headerCell.attributedStringValue.string as NSString
            attributes = column.headerCell.attributedStringValue.attributes(at: 0, effectiveRange: nil)
        } else {
            baseString = column.title as NSString
            attributes = [.font: column.headerCell.font ?? NSFont.systemFont(ofSize: 12, weight: .semibold)]
        }
        let size = baseString.size(withAttributes: attributes)
        let indicatorWidth: CGFloat = tableView.indicatorImage(in: column) != nil ? 16 : 0
        return ceil(size.width) + (ResultsGridMetrics.horizontalPadding * 2) + indicatorWidth + 4
    }

    func widestCellWidth(forColumn column: Int, tableView: NSTableView) -> CGFloat {
        guard column >= 0, tableView.numberOfRows > 0 else { return 0 }
        let padding = ResultsGridMetrics.horizontalPadding * 2
        let columnInfo = column < parent.query.displayedColumns.count ? parent.query.displayedColumns[column] : nil
        var maxWidth = CGFloat.zero
        let sampleCount = isSplitResizing ? min(tableView.numberOfRows, 32) : min(tableView.numberOfRows, ResultsGridMetrics.maxAutoWidthSampleCount)
        if sampleCount == 0 { return ceil(maxWidth) + padding + 6 }
        let sampledRows = makeSampledRows(total: tableView.numberOfRows, count: sampleCount)
        for row in sampledRows {
            let sourceRow = resolvedRowIndex(for: row)
            guard sourceRow >= 0 else { continue }
            let value = parent.query.valueForDisplay(row: sourceRow, column: column)
            let kind = ResultGridValueClassifier.kind(for: columnInfo, value: value)
            let style = fallbackResultGridStyle(for: kind)
            let displayString = (value ?? (kind == .null ? "NULL" : "")) as NSString
            let measured = displayString.size(withAttributes: [.font: resolvedFont(for: style)]).width
            maxWidth = max(maxWidth, measured)
        }
        return ceil(maxWidth) + padding + 6
    }

    private func makeSampledRows(total: Int, count: Int) -> [Int] {
        if count >= total { return Array(0..<total) }
        var result: [Int] = []; let step = max(1, total / count)
        var i = 0; while i < total && result.count < count { result.append(i); i += step }
        if result.count < count { for tail in stride(from: total-1, through: result.last ?? 0, by: -1) { result.append(tail); if result.count >= count { break } } }
        return result
    }

    func applyHeaderStyle(to tableView: NSTableView) {
        for column in tableView.tableColumns {
            column.headerCell = NSTableHeaderCell(textCell: column.title)
            column.headerCell.controlSize = .regular; column.headerCell.alignment = .left; column.headerCell.title = column.title; column.headerCell.isHighlighted = false
        }
        tableView.headerView?.needsDisplay = true
    }

    func updateHeaderIndicators() {
        guard let tableView else { return }
        for col in tableView.tableColumns { tableView.setIndicatorImage(nil, in: col) }
        if let sort = parent.activeSort, let idx = parent.query.displayedColumns.firstIndex(where: { $0.name == sort.column }), idx < tableView.tableColumns.count {
            let col = tableView.tableColumns[idx]; let img = NSImage(named: sort.ascending ? NSImage.touchBarGoUpTemplateName : NSImage.touchBarGoDownTemplateName)
            tableView.setIndicatorImage(img, in: col)
        }
    }
}
#endif

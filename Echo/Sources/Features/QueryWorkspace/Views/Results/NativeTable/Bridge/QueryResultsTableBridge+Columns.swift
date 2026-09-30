#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {

    func reloadColumns() -> Bool {
        guard let tableView else { return false }
        let columnIDs = parent.displayedColumns.map(\.id)
        let columnsChanged = tableView.tableColumns.count != columnIDs.count || columnIDs != cachedColumnIDs
        var headerNeedsRefresh = false

        if columnsChanged {
            while tableView.tableColumns.count > 0 { tableView.removeTableColumn(tableView.tableColumns[0]) }
            addDataColumns(to: tableView)
            headerNeedsRefresh = true
        } else {
            for (offset, column) in parent.displayedColumns.enumerated() {
                let tableColumn = tableView.tableColumns[offset]
                if tableColumn.title != column.name { tableColumn.title = column.name; headerNeedsRefresh = true }
                let minWidth = minimumWidth(for: column)
                if abs(tableColumn.minWidth - minWidth) > 1 {
                    tableColumn.minWidth = minWidth
                    if tableColumn.width < minWidth { tableColumn.width = minWidth }
                }
                if tableColumn.maxWidth < CGFloat.greatestFiniteMagnitude {
                    tableColumn.maxWidth = .greatestFiniteMagnitude
                }
                tableColumn.headerCell.alignment = .left
            }
        }
        tableView.headerView?.needsDisplay = true
        if headerNeedsRefresh { applyHeaderStyle(to: tableView) }
        cachedColumnKinds = parent.displayedColumns.map { ResultGridValueClassifier.kind(for: $0, value: "") }
        refreshColumnForms(parent.displayedColumns)
        cachedColumnIDs = columnIDs
        return columnsChanged
    }

    func addDataColumns(to tableView: NSTableView) {
        let hidden = persistedState?.hiddenColumnIndices ?? []
        let classification = parent.dataClassification
        let savedWidths = persistedState?.cachedColumnWidths ?? [:]
        for (index, column) in parent.displayedColumns.enumerated() {
            guard !hidden.contains(index) else { continue }
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("data-\(column.id)"))
            tableColumn.title = column.name
            tableColumn.minWidth = minimumWidth(for: column)
            tableColumn.maxWidth = .greatestFiniteMagnitude
            tableColumn.isEditable = false
            tableColumn.resizingMask = [.userResizingMask]
            let headerCell = ResultTableHeaderCell(textCell: column.name)
            headerCell.columnSensitivity = classification?.classification(forColumnAt: index)
            headerCell.typeName = column.dataType
            tableColumn.headerCell = headerCell
            tableColumn.headerCell.controlSize = .regular; tableColumn.headerCell.alignment = .left
            tableColumn.headerCell.font = ResultTableHeaderCell.nameFont
            if let sensitivity = headerCell.columnSensitivity {
                tableColumn.headerToolTip = sensitivity.summary + " (\(sensitivity.effectiveRank.displayName))"
            }
            tableView.addTableColumn(tableColumn)
            // Use persisted width from a previous tab visit when available,
            // skipping the expensive idealWidth() measurement entirely.
            if let savedWidth = savedWidths[column.id], savedWidth > 0 {
                tableColumn.width = max(savedWidth, tableColumn.minWidth)
            } else {
                let visibleColumnIndex = tableView.tableColumns.count - 1
                let measuredWidth = idealWidth(forVisibleColumnAt: visibleColumnIndex, in: tableView)
                let initialMax = maximumWidth(for: column)
                tableColumn.width = min(max(measuredWidth, tableColumn.minWidth), initialMax)
            }
        }
    }

    /// Captures current column widths into the persisted grid state so they
    /// can be restored instantly on tab switch without re-measuring.
    func saveColumnWidths() {
        guard let tableView, let state = persistedState else { return }
        var widths: [String: CGFloat] = [:]
        for tableColumn in tableView.tableColumns {
            let id = tableColumn.identifier.rawValue.replacingOccurrences(of: "data-", with: "")
            widths[id] = tableColumn.width
        }
        state.cachedColumnWidths = widths
    }

    func minimumWidth(for column: ColumnInfo) -> CGFloat {
        let type = column.dataType.lowercased()
        if type.contains("bool") || type == "bit" { return ResultsGridMetrics.minimumColumnWidth }
        if type.contains("guid") || type.contains("uniqueidentifier") || type.contains("uuid") { return 180 }
        if type.contains("date") || type.contains("time") { return 124 }
        if type.contains("int") || type.contains("numeric") || type.contains("decimal") || type.contains("float") || type.contains("double") || type.contains("money") { return 72 }
        if type.contains("json") || type.contains("xml") || type.contains("text") { return 96 }
        return 80
    }

    func maximumWidth(for column: ColumnInfo) -> CGFloat {
        let type = column.dataType.lowercased()
        if type.contains("guid") || type.contains("uniqueidentifier") || type.contains("uuid") {
            return 300
        }
        if type.contains("date") || type.contains("time") {
            return 240
        }
        return ResultsGridMetrics.maximumColumnWidth
    }

    func idealWidth(forVisibleColumnAt column: Int, in tableView: NSTableView) -> CGFloat {
        guard column >= 0, column < tableView.tableColumns.count else { return 0 }
        if column >= parent.displayedColumns.count {
            let tableColumn = tableView.tableColumns[column]
            return max(tableColumn.minWidth, tableColumn.width)
        }
        let tableColumn = tableView.tableColumns[column]
        let desired = max(headerContentWidth(for: tableColumn, in: tableView), widestCellWidth(forColumn: column, tableView: tableView))
        let maxWidth = tableColumn.maxWidth > 0 ? tableColumn.maxWidth : .greatestFiniteMagnitude
        return min(max(desired, tableColumn.minWidth), maxWidth)
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
        // The type line may be wider than the name; the sort arrow always has room.
        let typeName = (column.headerCell as? ResultTableHeaderCell)?.typeName ?? ""
        let typeWidth = (typeName as NSString).size(withAttributes: [.font: ResultTableHeaderCell.typeFont]).width
        let indicatorWidth = ResultsGridMetrics.sortIndicatorSize + SpacingTokens.xxs
        return ceil(max(size.width, typeWidth)) + (ResultsGridMetrics.contentHorizontalPadding * 2) + indicatorWidth + 4
    }

    func widestCellWidth(forColumn column: Int, tableView: NSTableView) -> CGFloat {
        guard column >= 0, tableView.numberOfRows > 0 else { return 0 }
        let padding = ResultsGridMetrics.contentHorizontalPadding * 2
        let columnInfo = column < parent.displayedColumns.count ? parent.displayedColumns[column] : nil
        var maxWidth = CGFloat.zero
        let sampleCount = isSplitResizing ? min(tableView.numberOfRows, 32) : min(tableView.numberOfRows, ResultsGridMetrics.maxAutoWidthSampleCount)
        if sampleCount == 0 { return ceil(maxWidth) + padding + 6 }
        let sampledRows = makeSampledRows(total: tableView.numberOfRows, count: sampleCount)
        for row in sampledRows {
            let sourceRow = resolvedRowIndex(for: row)
            guard sourceRow >= 0 else { continue }
            let value = queryState.valueForDisplay(row: sourceRow, column: column)
            let kind = ResultGridValueClassifier.kind(for: columnInfo, value: value)
            let style = fallbackResultGridStyle(for: kind)
            let form = column < cachedColumnForms.count ? cachedColumnForms[column] : .plain
            let shown = value.map { form == .decimal ? $0 : ResultCellValueForm.shown($0, form: form).text }
            let displayString = (shown ?? (kind == .null ? "NULL" : "")) as NSString
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
        let classification = parent.dataClassification
        for (offset, column) in tableView.tableColumns.enumerated() {
            if !(column.headerCell is ResultTableHeaderCell) {
                column.headerCell = ResultTableHeaderCell(textCell: column.title)
            }
            if let headerCell = column.headerCell as? ResultTableHeaderCell {
                headerCell.columnSensitivity = classification?.classification(forColumnAt: offset)
                if let sensitivity = headerCell.columnSensitivity {
                    column.headerToolTip = sensitivity.summary + " (\(sensitivity.effectiveRank.displayName))"
                } else {
                    column.headerToolTip = nil
                }
            }
            column.headerCell.controlSize = .regular
            column.headerCell.alignment = .left
            column.headerCell.title = column.title
            column.headerCell.font = ResultTableHeaderCell.nameFont
            column.headerCell.isHighlighted = false
            let dataIndex = visibleDataIndex(for: offset)
            if let headerCell = column.headerCell as? ResultTableHeaderCell,
               dataIndex >= 0, dataIndex < parent.displayedColumns.count {
                headerCell.typeName = parent.displayedColumns[dataIndex].dataType
            }
        }
        updateHeaderIndicators()
        tableView.headerView?.needsDisplay = true
    }

    /// Marks the sorted column's header; its cell draws an SF chevron (plan R2).
    func updateHeaderIndicators() {
        guard let tableView else { return }
        let sortedName = parent.activeSort?.column
        for (offset, column) in tableView.tableColumns.enumerated() {
            guard let headerCell = column.headerCell as? ResultTableHeaderCell else { continue }
            let dataIndex = visibleDataIndex(for: offset)
            let isSorted = dataIndex >= 0 && dataIndex < parent.displayedColumns.count
                && parent.displayedColumns[dataIndex].name == sortedName
            headerCell.sortState = isSorted ? ((parent.activeSort?.ascending ?? true) ? .ascending : .descending) : .none
        }
        tableView.headerView?.needsDisplay = true
    }

    /// A click on a header's sort arrow: ascending, then descending, then no sort.
    func cycleSort(forVisibleColumn column: Int) {
        let dataIndex = visibleDataIndex(for: column)
        guard dataIndex >= 0, dataIndex < parent.displayedColumns.count else { return }
        let name = parent.displayedColumns[dataIndex].name
        let action: QueryResultsTableView.HeaderSortAction
        if let sort = parent.activeSort, sort.column == name {
            action = sort.ascending ? .descending : .clear
        } else {
            action = .ascending
        }
        parent.onSort(dataIndex, action)
    }
}
#endif

#if os(iOS)
import UIKit

extension ResultGridCoordinator {
    internal func updateLayoutIfNeeded() {
        guard !columns.isEmpty else {
            layout.configure(columnWidths: [], numberOfSections: 0)
            return
        }

        var widths: [CGFloat] = [ResultGridMetrics.indexColumnWidth]
        widths.append(contentsOf: columns.map(widthForColumn(_:)))
        layout.configure(columnWidths: widths, numberOfSections: displayedRowCount + 1)
        collectionView.backgroundColor = palette.background
    }

    internal func reloadIfNeeded() {
        let columnIDs = columns.map(\.id)
        let columnsChanged = columnIDs != cachedColumnIDs
        let rowCountChanged = displayedRowCount != cachedRowCount
        let rowOrderChanged = rowOrder != cachedRowOrder

        if columnsChanged || rowCountChanged || rowOrderChanged {
            cachedColumnIDs = columnIDs
            cachedRowCount = displayedRowCount
            cachedRowOrder = rowOrder
            selectionRegion = nil
            selectionAnchor = nil
            selectionFocus = nil
            rowSelectionAnchor = nil
            columnSelectionAnchor = nil
            dragContext = nil
            collectionView.reloadData()
        }
    }

    internal func refreshVisibleCells() {
        guard !columns.isEmpty else { return }
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? ResultGridCell else { continue }
            configure(cell: cell, at: indexPath)
        }
    }

    internal func widthForColumn(_ column: ColumnInfo) -> CGFloat {
        let type = column.dataType.lowercased()
        if type.contains("bool") { return 80 }
        if type.contains("int") || type.contains("numeric") || type.contains("decimal") || type.contains("float") || type.contains("double") || type.contains("money") {
            return 120
        }
        if type.contains("date") || type.contains("time") {
            return 160
        }
        return 200
    }

    internal func resolvedDataRowIndex(forDisplayed row: Int) -> Int {
        if !rowOrder.isEmpty, row >= 0, row < rowOrder.count {
            return rowOrder[row]
        }
        return row
    }

    internal func valueForDisplay(row: Int, column: Int) -> String? {
        guard let query = query else { return nil }
        let dataRow = resolvedDataRowIndex(forDisplayed: row)
        guard dataRow >= 0, dataRow < query.totalAvailableRowCount else { return nil }
        return query.valueForDisplay(row: dataRow, column: column)
    }

    internal func isRowInSelection(_ row: Int) -> Bool {
        selectionRegion?.containsRow(row) ?? false
    }

    internal func isColumnInSelection(_ column: Int) -> Bool {
        selectionRegion?.containsColumn(column) ?? false
    }

    internal func isColumnHighlighted(_ column: Int) -> Bool {
        if isColumnInSelection(column) { return true }
        if let highlightedColumnIndex, highlightedColumnIndex == column { return true }
        return false
    }

    internal func isCellSelected(row: Int, column: Int) -> Bool {
        guard let region = selectionRegion else { return false }
        return region.contains(SelectedCell(row: row, column: column))
    }

    internal func isAlternateRow(_ row: Int) -> Bool {
        palette.alternateRow != nil && row % 2 == 1
    }

    internal func sortIndicator(for columnIndex: Int) -> SortIndicator? {
        guard columnIndex >= 0, columnIndex < columns.count else { return nil }
        guard let activeSort else { return nil }
        return activeSort.column == columns[columnIndex].name
            ? (activeSort.ascending ? .ascending : .descending)
            : nil
    }

    internal func configure(cell: ResultGridCell, at indexPath: IndexPath) {
        guard !columns.isEmpty else { return }
        if indexPath.section == 0 {
            configureHeaderCell(cell, at: indexPath)
        } else {
            configureDataCell(cell, at: indexPath)
        }
    }

    private func configureHeaderCell(_ cell: ResultGridCell, at indexPath: IndexPath) {
        if indexPath.item == 0 {
            cell.configure(
                text: "#",
                kind: .headerIndex,
                palette: palette,
                isHighlightedColumn: false,
                isRowSelected: false,
                isCellSelected: false,
                sortIndicator: nil,
                isNullValue: false,
                isAlternateRow: false
            )
        } else {
            let columnIndex = indexPath.item - 1
            guard columnIndex < columns.count else { return }
            let column = columns[columnIndex]
            let highlighted = isColumnHighlighted(columnIndex)
            cell.configure(
                text: column.name,
                kind: .header,
                palette: palette,
                isHighlightedColumn: highlighted,
                isRowSelected: false,
                isCellSelected: false,
                sortIndicator: sortIndicator(for: columnIndex),
                isNullValue: false,
                isAlternateRow: false
            )
        }
    }

    private func configureDataCell(_ cell: ResultGridCell, at indexPath: IndexPath) {
        let rowIndex = indexPath.section - 1
        guard rowIndex < displayedRowCount else { return }
        if indexPath.item == 0 {
            let rowSelected = isRowInSelection(rowIndex)
            cell.configure(
                text: "\(rowIndex + 1)",
                kind: .rowIndex,
                palette: palette,
                isHighlightedColumn: false,
                isRowSelected: rowSelected,
                isCellSelected: rowSelected,
                sortIndicator: nil,
                isNullValue: false,
                isAlternateRow: false
            )
        } else {
            let columnIndex = indexPath.item - 1
            guard columnIndex < columns.count else { return }
            let value = valueForDisplay(row: rowIndex, column: columnIndex)
            let column = columns[columnIndex]
            let valueKind = ResultGridValueClassifier.kind(for: column, value: value)
            let text = value ?? "NULL"
            let isNull = value == nil
            let highlighted = isColumnHighlighted(columnIndex)
            let rowSelected = isRowInSelection(rowIndex)
            let cellSelected = isCellSelected(row: rowIndex, column: columnIndex)
            cell.configure(
                text: text,
                kind: .data,
                palette: palette,
                isHighlightedColumn: highlighted,
                isRowSelected: rowSelected,
                isCellSelected: cellSelected,
                sortIndicator: nil,
                isNullValue: isNull,
                isAlternateRow: isAlternateRow(rowIndex),
                valueKind: valueKind
            )
        }
    }
}
#endif

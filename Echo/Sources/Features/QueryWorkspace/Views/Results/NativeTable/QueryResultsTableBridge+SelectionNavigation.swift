#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {

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

}
#endif

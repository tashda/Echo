#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let tableView else { return }
        menu.removeAllItems()

        if menu === headerMenu {
            let clickedColumn = menuColumnIndex ?? tableView.clickedColumn
            guard clickedColumn >= 0 else {
                menuColumnIndex = nil
                return
            }
            menuColumnIndex = clickedColumn

            guard let dataIndex = menuColumnIndex,
                  dataIndex < parent.query.displayedColumns.count else { return }

            selectColumn(at: dataIndex, in: tableView)

            let ascendingItem = NSMenuItem(title: "Sort Ascending", action: #selector(sortAscending), keyEquivalent: "")
            ascendingItem.target = self
            if let sort = parent.activeSort,
               sort.column == parent.query.displayedColumns[dataIndex].name,
               sort.ascending {
                ascendingItem.state = .on
            }
            menu.addItem(ascendingItem)

            let descendingItem = NSMenuItem(title: "Sort Descending", action: #selector(sortDescending), keyEquivalent: "")
            descendingItem.target = self
            if let sort = parent.activeSort,
               sort.column == parent.query.displayedColumns[dataIndex].name,
               !sort.ascending {
                descendingItem.state = .on
            }
            menu.addItem(descendingItem)

            menu.addItem(.separator())

            let copyColumnItem = NSMenuItem(title: "Copy Column", action: #selector(copyColumnPlain), keyEquivalent: "c")
            copyColumnItem.target = self
            copyColumnItem.isEnabled = hasCopyableSelection()
            copyColumnItem.keyEquivalentModifierMask = [.command]
            if #available(macOS 11.0, *) {
                copyColumnItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            }
            menu.addItem(copyColumnItem)

            let copyColumnWithHeadersItem = NSMenuItem(title: "Copy Column with Headers", action: #selector(copyColumnWithHeaders), keyEquivalent: "c")
            copyColumnWithHeadersItem.target = self
            copyColumnWithHeadersItem.isEnabled = hasCopyableSelection()
            copyColumnWithHeadersItem.keyEquivalentModifierMask = [.command, .shift]
            if #available(macOS 11.0, *) {
                copyColumnWithHeadersItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: nil)
            }
            menu.addItem(copyColumnWithHeadersItem)
        } else if menu === cellMenu {
            updateCellMenu(menu, tableView: tableView)
        }
    }

    @objc func sortAscending() {
        guard let dataIndex = menuColumnIndex else { return }
        parent.onSort(dataIndex, .ascending)
    }

    @objc func sortDescending() {
        guard let dataIndex = menuColumnIndex else { return }
        parent.onSort(dataIndex, .descending)
    }

    @objc func copyColumnPlain() {
        copySelection(includeHeaders: false)
    }

    @objc func copyColumnWithHeaders() {
        copySelection(includeHeaders: true)
    }

    func updateCellMenu(_ menu: NSMenu, tableView: NSTableView) {
        menuColumnIndex = nil
        ensureSelectionForContextMenu(tableView: tableView)

        let hasSelection = hasCopyableSelection()

        let copyItem = NSMenuItem(title: "Copy", action: #selector(copySelectionPlain), keyEquivalent: "c")
        copyItem.target = self
        if #available(macOS 11.0, *) {
            copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        }
        copyItem.isEnabled = hasSelection
        copyItem.keyEquivalentModifierMask = [.command]
        menu.addItem(copyItem)

        let copyHeadersItem = NSMenuItem(title: "Copy with Headers", action: #selector(copySelectionWithHeaders), keyEquivalent: "c")
        copyHeadersItem.target = self
        if #available(macOS 11.0, *) {
            copyHeadersItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: nil)
        }
        copyHeadersItem.isEnabled = hasSelection
        copyHeadersItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(copyHeadersItem)
    }

    func prepareHeaderContextMenu(at column: Int?) {
        if let column, column >= 0 {
            menuColumnIndex = column
        } else {
            menuColumnIndex = nil
        }
    }

    func selectColumn(at index: Int, in tableView: NSTableView) {
        let maxRow = tableView.numberOfRows - 1
        guard index >= 0, index < tableView.tableColumns.count, maxRow >= 0 else {
            setSelectionRegion(nil, tableView: tableView)
            return
        }

        let top = QueryResultsTableView.SelectedCell(row: 0, column: index)
        let bottom = QueryResultsTableView.SelectedCell(row: maxRow, column: index)
        setSelectionRegion(SelectedRegion(start: top, end: bottom), tableView: tableView)
        selectionAnchor = top
        selectionFocus = bottom
        endSelectionDrag()
        tableView.highlightedTableColumn = tableView.tableColumns[index]
    }

    func ensureSelectionForContextMenu(tableView: NSTableView) {
        let cell = consumeContextMenuCell()
            ?? resolvedCell(forRow: tableView.clickedRow, column: tableView.clickedColumn, tableView: tableView)
        guard let cell else { return }

        if let region = selectionRegion, region.contains(cell) {
            tableView.deselectAll(nil)
            tableView.selectionHighlightStyle = .none
            return
        }

        setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView)
        parent.onClearColumnHighlight()
    }

    func hasCopyableSelection() -> Bool {
        guard let tableView else { return false }

        if let selectionRegion {
            let columnCount = parent.query.displayedColumns.count
            let rowCount = tableView.numberOfRows
            guard columnCount > 0, rowCount > 0 else { return false }

            let lowerRow = max(selectionRegion.normalizedRowRange.lowerBound, 0)
            let upperRow = min(selectionRegion.normalizedRowRange.upperBound, rowCount - 1)
            guard upperRow >= lowerRow else { return false }

            let lowerColumn = max(selectionRegion.normalizedColumnRange.lowerBound, 0)
            let upperColumn = min(selectionRegion.normalizedColumnRange.upperBound, columnCount - 1)
            guard upperColumn >= lowerColumn else { return false }

            return true
        }

        return !tableView.selectedRowIndexes.isEmpty
    }

    @objc func copySelectionPlain() {
        copySelection(includeHeaders: false)
    }

    @objc func copySelectionWithHeaders() {
        copySelection(includeHeaders: true)
    }

    func copySelection(includeHeaders: Bool) {
        guard let tableView else { return }
        let columns = parent.query.displayedColumns
        guard !columns.isEmpty else { return }

        let totalRows = parent.query.totalAvailableRowCount
        guard totalRows > 0 else { return }

        let columnIndices: [Int]
        let visibleRows: [Int]

        if let selectionRegion {
            let maxColumnIndex = columns.count - 1
            let lowerColumn = max(selectionRegion.normalizedColumnRange.lowerBound, 0)
            let upperColumn = min(selectionRegion.normalizedColumnRange.upperBound, maxColumnIndex)
            guard upperColumn >= lowerColumn else { return }
            columnIndices = Array(lowerColumn...upperColumn)

            let maxVisibleRow = tableView.numberOfRows - 1
            guard maxVisibleRow >= 0 else { return }
            let lowerRow = max(selectionRegion.normalizedRowRange.lowerBound, 0)
            let upperRow = min(selectionRegion.normalizedRowRange.upperBound, maxVisibleRow)
            guard upperRow >= lowerRow else { return }
            visibleRows = Array(lowerRow...upperRow)
        } else {
            let selectedIndexes = tableView.selectedRowIndexes
            guard !selectedIndexes.isEmpty else { return }
            visibleRows = selectedIndexes.sorted()
            columnIndices = Array(0..<columns.count)
        }

        let sourceRows: [Int] = visibleRows.compactMap { visible in
            guard visible >= 0 else { return nil }
            let source = resolvedRowIndex(for: visible)
            guard source >= 0, source < totalRows else { return nil }
            return source
        }

        guard !sourceRows.isEmpty, !columnIndices.isEmpty else { return }

        var lines: [String] = []
        if includeHeaders {
            let header = columnIndices.map { columns[$0].name }
            lines.append(header.joined(separator: "\t"))
        }

        for row in sourceRows {
            let values = columnIndices.map { parent.query.valueForDisplay(row: row, column: $0) ?? "" }
            lines.append(values.joined(separator: "\t"))
        }

        let export = lines.joined(separator: "\n")
        PlatformClipboard.copy(export)
        clipboardHistory.record(
            .resultGrid(includeHeaders: includeHeaders),
            content: export,
            metadata: parent.query.clipboardMetadata
        )
    }

    func performMenuCopy(in tableView: NSTableView) -> Bool {
        guard self.tableView === tableView else { return false }
        copySelection(includeHeaders: false)
        return true
    }

    func consumeContextMenuCell() -> QueryResultsTableView.SelectedCell? {
        defer { contextMenuCell = nil }
        return contextMenuCell
    }

    func notifyJsonSelection(_ region: SelectedRegion?) {
        guard let region,
              region.start.row == region.end.row,
              region.start.column == region.end.column,
              let selection = makeJsonSelection(for: region.start) else {
            if lastJsonSelection != nil {
                lastJsonSelection = nil
                parent.onJsonEvent(.selectionChanged(nil))
            }
            return
        }

        if lastJsonSelection != selection {
            lastJsonSelection = selection
            parent.onJsonEvent(.selectionChanged(selection))
        }
    }

    func notifyForeignKeySelection(_ region: SelectedRegion?) {
        guard parent.foreignKeyDisplayMode != .disabled else {
            lastForeignKeySelection = nil
            parent.onForeignKeyEvent(.selectionChanged(nil))
            return
        }

        guard let region,
              region.start.row == region.end.row,
              region.start.column == region.end.column,
              let selection = makeForeignKeySelection(for: region.start) else {
            if lastForeignKeySelection != nil {
                lastForeignKeySelection = nil
                parent.onForeignKeyEvent(.selectionChanged(nil))
            }
            return
        }

        if lastForeignKeySelection != selection {
            lastForeignKeySelection = selection
            parent.onForeignKeyEvent(.selectionChanged(selection))
        }
    }

    func makeJsonSelection(for cell: QueryResultsTableView.SelectedCell) -> QueryResultsTableView.JsonSelection? {
        guard cell.column >= 0,
              cell.column < parent.query.displayedColumns.count else { return nil }
        let columnInfo = parent.query.displayedColumns[cell.column]
        let sourceRowIndex = resolvedRowIndex(for: cell.row)
        guard sourceRowIndex >= 0,
              let rawValue = parent.query.valueForDisplay(row: sourceRowIndex, column: cell.column) else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let kind = ResultGridValueClassifier.kind(for: columnInfo, value: rawValue)
        guard kind == .json else { return nil }
        guard let jsonValue = try? JsonValue.parse(from: rawValue) else { return nil }
        return QueryResultsTableView.JsonSelection(
            sourceRowIndex: sourceRowIndex,
            displayedRowIndex: cell.row,
            columnIndex: cell.column,
            columnName: columnInfo.name,
            rawValue: rawValue,
            jsonValue: jsonValue
        )
    }

    func makeForeignKeySelection(for cell: QueryResultsTableView.SelectedCell) -> QueryResultsTableView.ForeignKeySelection? {
        guard cell.column >= 0,
              cell.column < parent.query.displayedColumns.count else { return nil }
        let columnInfo = parent.query.displayedColumns[cell.column]
        if columnInfo.foreignKey == nil {
            if !requestedForeignKeyColumns.contains(cell.column) {
                requestedForeignKeyColumns.insert(cell.column)
                parent.onForeignKeyEvent(.requestMetadata(columnIndex: cell.column, columnName: columnInfo.name))
            }
            return nil
        }
        guard let reference = columnInfo.foreignKey else { return nil }
        let rowIndex = resolvedRowIndex(for: cell.row)
        guard let rawValue = parent.query.valueForDisplay(row: rowIndex, column: cell.column) else { return nil }
        let kind = ResultGridValueClassifier.kind(for: columnInfo, value: rawValue)
        return QueryResultsTableView.ForeignKeySelection(
            row: rowIndex,
            column: cell.column,
            value: rawValue,
            columnName: columnInfo.name,
            reference: reference,
            valueKind: kind
        )
    }
}
#endif

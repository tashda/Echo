#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if suppressRowsDuringClear { return 0 }
        return parent.rowOrder.isEmpty ? parent.query.displayedRowCount : parent.rowOrder.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("result-row")
        let rowView = (tableView.makeView(withIdentifier: identifier, owner: self) as? ResultTableRowView) ?? {
            let view = ResultTableRowView()
            view.identifier = identifier
            return view
        }()
        rowView.configure(
            row: row,
            colorProvider: { [weak self] index in self?.rowBackgroundColor(for: index) ?? .clear },
            highlightProvider: { [weak self, weak tableView] view, index in guard let self, let tableView else { return nil }; return self.selectionRenderInfo(forRow: index, rowView: view, tableView: tableView) }
        )
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, let dataIndex = dataColumnIndex(for: tableColumn) else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("data-cell-\(dataIndex)")
        let cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? ResultTableDataCellView ?? makeDataCellView(identifier: identifier)
        configureCellView(cellView, dataIndex: dataIndex, tableView: tableView, row: row)
        cellView.frame = NSRect(x: 0, y: 0, width: tableColumn.width, height: tableView.rowHeight)
        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool { false }

    func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn column: Int) -> CGFloat {
        idealWidth(forVisibleColumnAt: column, in: tableView)
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard let dataIndex = dataColumnIndex(for: tableColumn) else { return }
        parent.onColumnTap(dataIndex); selectColumn(at: dataIndex, in: tableView)
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let clickedColumn = tableView.clickedColumn
        if clickedColumn >= 0 {
            let cell = QueryResultsTableView.SelectedCell(row: row, column: clickedColumn)
            if !isDraggingCellSelection {
                setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView)
                isDraggingCellSelection = true
            }
            return false
        }
        if let event = NSApp.currentEvent {
            let location = tableView.convert(event.locationInWindow, from: nil); let column = tableView.column(at: location)
            if column >= 0 {
                let cell = QueryResultsTableView.SelectedCell(row: row, column: column)
                if !isDraggingCellSelection {
                    setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView)
                }
                return false
            }
        }
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView else { return }; let hasRowSelection = !tableView.selectedRowIndexes.isEmpty
        if selectionRegion != nil, hasRowSelection { tableView.deselectAll(nil); return }
        if hasRowSelection { endSelectionDrag(); setSelectionRegion(nil, tableView: tableView) }
    }

    // MARK: - Row and Cell Configuration

    func rowBackgroundColor(for row: Int) -> NSColor { cachedRowBackgroundColor }

    func dataColumnIndex(for tableColumn: NSTableColumn) -> Int? {
        guard let tableView else { return nil }
        let tableIndex = tableView.column(withIdentifier: tableColumn.identifier)
        guard tableIndex >= 0 else { return nil }
        return visibleDataIndex(for: tableIndex)
    }

    func makeDataCellView(identifier: NSUserInterfaceItemIdentifier) -> ResultTableDataCellView {
        let cellView = ResultTableDataCellView(); cellView.identifier = identifier; let textField = cellView.contentTextField
        if !(textField.cell is VerticallyCenteredTextFieldCell) { textField.cell = VerticallyCenteredTextFieldCell(textCell: "") }
        if let cell = textField.cell as? VerticallyCenteredTextFieldCell { cell.isBordered = false; cell.backgroundColor = .clear; cell.usesSingleLineMode = true; cell.truncatesLastVisibleLine = true; cell.alignment = .left }
        return cellView
    }

    func configureCellView(_ cellView: ResultTableDataCellView, dataIndex: Int, tableView: NSTableView, row: Int) {
        let sourceIndex = resolvedRowIndex(for: row)
        guard sourceIndex >= 0 else {
            let style = fallbackResultGridStyle(for: .text)
            cellView.apply(text: "", font: resolvedFont(for: style), textColor: style.nsColor)
            cellView.configureIcon(nil); return
        }
        let rawValue = displayedRowValues(for: sourceIndex)?[safe: dataIndex] ?? parent.query.valueForDisplay(row: sourceIndex, column: dataIndex)
        let columnInfo = dataIndex < parent.query.displayedColumns.count ? parent.query.displayedColumns[dataIndex] : nil
        let kind = (rawValue == nil) ? .null : (dataIndex < cachedColumnKinds.count ? cachedColumnKinds[dataIndex] : ResultGridValueClassifier.kind(for: columnInfo, value: rawValue))
        let style = cachedResultGridStyles[kind] ?? { let s = fallbackResultGridStyle(for: kind); cachedResultGridStyles[kind] = s; return s }()
        let font = resolvedFont(for: style); let displayText = rawValue ?? (kind == .null ? "NULL" : "")
        let baseTextColor = cachedTextColors[kind] ?? { let c = dynamicNSColor(for: kind, style: style); cachedTextColors[kind] = c; return c }()
        cellView.apply(text: displayText, font: font, textColor: baseTextColor)
        let cellPosition = QueryResultsTableView.SelectedCell(row: row, column: dataIndex)
        if shouldShowForeignKeyIcon(forColumnInfo: columnInfo, value: rawValue) {
            cellView.configureIcon(symbolName: "arrow.up.right.square") { [weak self] in self?.activateForeignKey(at: cellPosition) }
        } else if shouldShowJsonIcon(forKind: kind, value: rawValue) {
            cellView.configureIcon(symbolName: "curlybraces") { [weak self] in self?.activateJson(at: cellPosition) }
        } else {
            cellView.configureIcon(nil)
        }
    }

    private func displayedRowValues(for sourceIndex: Int) -> [String?]? {
        if let cached = cachedDisplayedRows.get(sourceIndex) { return cached }
        guard let rowValues = parent.query.displayedRow(at: sourceIndex) else { return nil }
        cachedDisplayedRows.put(sourceIndex, value: rowValues)
        return rowValues
    }

    private func shouldShowForeignKeyIcon(forColumnInfo column: ColumnInfo?, value: String?) -> Bool {
        guard let column, column.foreignKey != nil, let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return false }
        return true
    }

    private func shouldShowJsonIcon(forKind kind: ResultGridValueKind, value: String?) -> Bool {
        guard kind == .json, let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return false }
        return true
    }

    private func activateForeignKey(at cell: QueryResultsTableView.SelectedCell) {
        if let tableView { setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView) }
        if let selection = makeForeignKeySelection(for: cell) { parent.onForeignKeyEvent(.activate(selection)) }
    }

    private func activateJson(at cell: QueryResultsTableView.SelectedCell) {
        if let tableView { setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView) }
        if let selection = makeJsonSelection(for: cell) { parent.onJsonEvent(.activate(selection)) }
    }

    private func dynamicNSColor(for kind: ResultGridValueKind, style: SQLEditorTokenPalette.ResultGridStyle) -> NSColor {
        if kind == .text, parent.colorOverrides.textHex == nil { return .labelColor }
        return style.nsColor
    }

    func refreshVisibleRowBackgrounds(_ tableView: NSTableView) {
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return }
        let lower = max(0, visibleRange.location); let upper = min(tableView.numberOfRows, lower + visibleRange.length)
        for row in lower..<upper {
            guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ResultTableRowView else { continue }
            rowView.configure(row: row, colorProvider: { [weak self] index in self?.rowBackgroundColor(for: index) ?? .clear }, highlightProvider: { [weak self, weak tableView] view, index in guard let self, let tableView else { return nil }; return self.selectionRenderInfo(forRow: index, rowView: view, tableView: tableView) })
        }
    }

    func refreshVisibleCellsAppearance(_ tableView: NSTableView) {
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return }
        let lower = max(0, visibleRange.location); let upper = min(tableView.numberOfRows, lower + visibleRange.length)
        for row in lower..<upper {
            guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) else { continue }
            for col in 0..<tableView.tableColumns.count { guard let cellView = rowView.view(atColumn: col) as? ResultTableDataCellView else { continue }; configureCellView(cellView, dataIndex: col, tableView: tableView, row: row) }
        }
    }

    func resolvedRowIndex(for visibleRow: Int) -> Int {
        let count = parent.rowOrder.isEmpty ? parent.query.displayedRowCount : parent.rowOrder.count
        guard visibleRow >= 0, visibleRow < count else { if visibleRow >= count { scheduleRowCountCorrection() }; return -1 }
        return parent.rowOrder.isEmpty ? visibleRow : parent.rowOrder[visibleRow]
    }
}

private extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }
#endif

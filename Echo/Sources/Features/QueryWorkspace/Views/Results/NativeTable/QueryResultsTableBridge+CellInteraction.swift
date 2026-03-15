#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {
    
    func deactivateActiveSelectableField(in tableView: NSTableView) {
        guard let field = activeSelectableField else { return }
        field.isSelectable = false
        if tableView.window?.firstResponder == field {
            tableView.window?.makeFirstResponder(tableView)
        }
        activeSelectableField = nil
    }

    func enqueueReloadWorkItem(_ workItem: DispatchWorkItem) {
        pendingReloadWorkItems.append(workItem)
        Task { @MainActor in workItem.perform() }
    }

    func notifyForeignKeySelection(_ region: SelectedRegion?) {
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

    struct SelectionData {
        let headers: [String]
        let rows: [[String?]]
        let columnIndices: [Int]
    }

    func gatherSelectionData() -> SelectionData? {
        guard let tableView else { return nil }
        let columns = parent.query.displayedColumns
        guard !columns.isEmpty else { return nil }

        let totalRows = parent.query.totalAvailableRowCount
        guard totalRows > 0 else { return nil }

        let columnIndices: [Int]
        let visibleRows: [Int]

        if let selectionRegion {
            let maxColumnIndex = columns.count - 1
            let lowerColumn = max(selectionRegion.normalizedColumnRange.lowerBound, 0)
            let upperColumn = min(selectionRegion.normalizedColumnRange.upperBound, maxColumnIndex)
            guard upperColumn >= lowerColumn else { return nil }
            columnIndices = Array(lowerColumn...upperColumn)

            let maxVisibleRow = tableView.numberOfRows - 1
            guard maxVisibleRow >= 0 else { return nil }
            let lowerRow = max(selectionRegion.normalizedRowRange.lowerBound, 0)
            let upperRow = min(selectionRegion.normalizedRowRange.upperBound, maxVisibleRow)
            guard upperRow >= lowerRow else { return nil }
            visibleRows = Array(lowerRow...upperRow)
        } else {
            let selectedIndexes = tableView.selectedRowIndexes
            guard !selectedIndexes.isEmpty else { return nil }
            visibleRows = selectedIndexes.sorted()
            columnIndices = Array(0..<columns.count)
        }

        let sourceRows: [Int] = visibleRows.compactMap { visible in
            guard visible >= 0 else { return nil }
            let source = resolvedRowIndex(for: visible)
            guard source >= 0, source < totalRows else { return nil }
            return source
        }

        guard !sourceRows.isEmpty, !columnIndices.isEmpty else { return nil }

        let headers = columnIndices.map { columns[$0].name }
        let rows: [[String?]] = sourceRows.map { row in
            columnIndices.map { parent.query.valueForDisplay(row: row, column: $0) }
        }

        return SelectionData(headers: headers, rows: rows, columnIndices: columnIndices)
    }

    func copySelection(includeHeaders: Bool) {
        guard let data = gatherSelectionData() else { return }
        let export = ResultTableExportFormatter.formatTSV(
            headers: data.headers,
            rows: data.rows,
            includeHeaders: includeHeaders
        )
        PlatformClipboard.copy(export)
        clipboardHistory.record(
            .resultGrid(includeHeaders: includeHeaders),
            content: export,
            metadata: parent.query.clipboardMetadata
        )
    }

    func copySelectionAs(format: ResultExportFormat) {
        guard let data = gatherSelectionData() else { return }
        let export = ResultTableExportFormatter.format(format, headers: data.headers, rows: data.rows)
        PlatformClipboard.copy(export)
        clipboardHistory.record(
            .resultGrid(includeHeaders: true),
            content: export,
            metadata: parent.query.clipboardMetadata
        )
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

    func fallbackResultGridStyle(for kind: ResultGridValueKind) -> SQLEditorTokenPalette.ResultGridStyle {
        if let overrideHex = colorOverrideHex(for: kind),
           let overrideColor = Color(hex: overrideHex) {
            return SQLEditorTokenPalette.ResultGridStyle(
                color: ColorRepresentable(color: overrideColor)
            )
        }
        let tone: SQLEditorPalette.Tone = AppearanceStore.shared.effectiveColorScheme == .dark ? .dark : .light
        let defaults = SQLEditorTokenPalette.ResultGridColors.defaults(for: tone)
        return defaults.style(for: kind)
    }

    func fireCellInspect(for cell: QueryResultsTableView.SelectedCell) {
        guard cell.column >= 0, cell.column < parent.query.displayedColumns.count else { return }
        let columnInfo = parent.query.displayedColumns[cell.column]
        let sourceRow = resolvedRowIndex(for: cell.row)
        guard sourceRow >= 0 else { return }
        let rawValue = parent.query.valueForDisplay(row: sourceRow, column: cell.column) ?? "NULL"
        let kind = ResultGridValueClassifier.kind(for: columnInfo, value: rawValue == "NULL" ? nil : rawValue)
        let content = CellValueInspectorContent(
            columnName: columnInfo.name,
            dataType: columnInfo.dataType,
            rawValue: rawValue,
            valueKind: kind
        )
        parent.onCellInspect?(content)
    }

    private func colorOverrideHex(for kind: ResultGridValueKind) -> String? {
        let overrides = parent.colorOverrides
        switch kind {
        case .null: return overrides.nullHex
        case .numeric: return overrides.numericHex
        case .boolean: return overrides.booleanHex
        case .temporal: return overrides.temporalHex
        case .binary: return overrides.binaryHex
        case .identifier: return overrides.identifierHex
        case .json: return overrides.jsonHex
        case .text: return overrides.textHex
        }
    }
}
#endif

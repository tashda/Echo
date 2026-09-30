#if os(macOS)
import AppKit

/// Round 21 (values in the grid): the per-column value forms, decimal alignment and Copy as Shown.
extension QueryResultsTableView.Coordinator {
    func refreshColumnForms(_ columns: [ColumnInfo]) {
        cachedColumnForms = zip(columns, cachedColumnKinds).map { ResultCellValueForm.form(kind: $1, dataType: $0.dataType) }
        cachedFractionDigits = Array(repeating: 0, count: columns.count)
    }

    /// The text a visible cell draws. A decimal wider than the column's widest fraction so far widens
    /// it and redraws the visible rows once, so the points line up.
    func shownValue(_ raw: String?, kind: ResultGridValueKind, dataIndex: Int, tableView: NSTableView) -> (text: String, countLength: Int) {
        guard let raw, kind != .boolean, dataIndex < cachedColumnForms.count else {
            return (ResultCellPresentation.displayText(raw, kind: kind), 0)
        }
        let form = cachedColumnForms[dataIndex]
        guard form == .decimal else { return ResultCellValueForm.shown(raw, form: form) }
        let digits = min(ResultCellValueForm.fractionDigits(raw), ResultCellValueForm.maxAlignedFractionDigits)
        if dataIndex < cachedFractionDigits.count, digits > cachedFractionDigits[dataIndex] {
            cachedFractionDigits[dataIndex] = digits
            scheduleFractionRefresh(tableView)
        }
        let columnDigits = dataIndex < cachedFractionDigits.count ? cachedFractionDigits[dataIndex] : 0
        return ResultCellValueForm.shown(raw, form: form, fractionDigits: columnDigits)
    }

    private func scheduleFractionRefresh(_ tableView: NSTableView) {
        guard !fractionRefreshScheduled else { return }
        fractionRefreshScheduled = true
        DispatchQueue.main.async { [weak self, weak tableView] in
            guard let self, let tableView else { return }
            self.fractionRefreshScheduled = false
            let visible = tableView.rows(in: tableView.visibleRect)
            guard visible.length > 0 else { return }
            tableView.reloadData(forRowIndexes: IndexSet(integersIn: visible.location..<(visible.location + visible.length)),
                                 columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
        }
    }

    @objc func copySelectionAsShown() {
        guard let data = gatherSelectionData() else { return }
        let columns = queryState.displayedColumns
        let rows = data.rows.map { row in
            zip(row, data.columnIndices).map { value, column -> String? in
                let info = column < columns.count ? columns[column] : nil
                let kind = value == nil ? .null : ResultGridValueClassifier.kind(for: info, value: value)
                let form = column < cachedColumnForms.count ? cachedColumnForms[column] : .plain
                return ResultCellValueForm.copiedAsShown(value, kind: kind, form: form)
            }
        }
        let export = ResultTableExportFormatter.formatTSV(headers: data.headers, rows: rows, includeHeaders: false)
        PlatformClipboard.copy(export)
        clipboardHistory.record(.resultGrid(includeHeaders: false), content: export, metadata: queryState.clipboardMetadata)
    }
}
#endif

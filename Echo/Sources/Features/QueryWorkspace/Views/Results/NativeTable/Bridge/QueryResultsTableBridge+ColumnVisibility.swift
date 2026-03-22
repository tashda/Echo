#if os(macOS)
import AppKit

extension QueryResultsTableView.Coordinator {

    func hideColumn(at dataIndex: Int) {
        guard let tableView else { return }
        persistedState?.hiddenColumnIndices.insert(dataIndex)
        rebuildVisibleColumns(in: tableView)
    }

    func showAllColumns() {
        guard let tableView else { return }
        persistedState?.hiddenColumnIndices.removeAll()
        rebuildVisibleColumns(in: tableView)
    }

    var hasHiddenColumns: Bool {
        guard let state = persistedState else { return false }
        return !state.hiddenColumnIndices.isEmpty
    }

    var hiddenColumnCount: Int {
        persistedState?.hiddenColumnIndices.count ?? 0
    }

    func visibleDataIndex(for tableColumnIndex: Int) -> Int {
        let hidden = persistedState?.hiddenColumnIndices ?? []
        guard !hidden.isEmpty else { return tableColumnIndex }
        let allColumns = queryState.displayedColumns
        var visibleCount = 0
        for i in 0..<allColumns.count {
            guard !hidden.contains(i) else { continue }
            if visibleCount == tableColumnIndex { return i }
            visibleCount += 1
        }
        return tableColumnIndex
    }

    func visibleColumnIndices() -> [Int] {
        let hidden = persistedState?.hiddenColumnIndices ?? []
        let total = queryState.displayedColumns.count
        guard !hidden.isEmpty else { return Array(0..<total) }
        return (0..<total).filter { !hidden.contains($0) }
    }

    private func rebuildVisibleColumns(in tableView: NSTableView) {
        saveColumnWidths()
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }
        let allColumns = queryState.displayedColumns
        let hidden = persistedState?.hiddenColumnIndices ?? []
        let savedWidths = persistedState?.cachedColumnWidths ?? [:]
        for (index, column) in allColumns.enumerated() {
            guard !hidden.contains(index) else { continue }
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("data-\(column.id)"))
            tableColumn.title = column.name
            tableColumn.minWidth = minimumWidth(for: column)
            tableColumn.maxWidth = maximumWidth(for: column)
            tableColumn.isEditable = false
            tableColumn.resizingMask = [.userResizingMask]
            if !(tableColumn.headerCell is ResultTableHeaderCell) {
                tableColumn.headerCell = ResultTableHeaderCell(textCell: column.name)
            }
            tableColumn.headerCell.controlSize = .regular
            tableColumn.headerCell.alignment = .left
            tableColumn.headerCell.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            tableView.addTableColumn(tableColumn)
            if let savedWidth = savedWidths[column.id], savedWidth > 0 {
                tableColumn.width = min(max(savedWidth, tableColumn.minWidth), tableColumn.maxWidth)
            } else {
                let visibleColumnIndex = tableView.tableColumns.count - 1
                let measuredWidth = idealWidth(forVisibleColumnAt: visibleColumnIndex, in: tableView)
                tableColumn.width = min(max(measuredWidth, tableColumn.minWidth), tableColumn.maxWidth)
            }
        }
        applyHeaderStyle(to: tableView)
        cachedColumnIDs = allColumns.map(\.id)
        cachedColumnKinds = allColumns.map { ResultGridValueClassifier.kind(for: $0, value: "") }
        tableView.reloadData()
        refreshVisibleRowBackgrounds(tableView)
    }
}
#endif

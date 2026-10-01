#if os(macOS)
import AppKit

/// A table column's position, without NSTableView's search.
///
/// `column(withIdentifier:)` walks every column; the table asks for a cell in every column of
/// every row that scrolls in, so a 100-column result did about 5,000 string comparisons per row
/// (traced 2026-10-01: half the time spent making cells). Positions are read once per set of
/// columns.
extension QueryResultsTableView.Coordinator {
    func tableColumnIndex(of tableColumn: NSTableColumn, in tableView: NSTableView) -> Int {
        if tableColumnPositions.count != tableView.numberOfColumns {
            rebuildTableColumnPositions(tableView)
        }
        if let index = tableColumnPositions[tableColumn.identifier] { return index }
        // A column this map hasn't seen: the columns changed under it.
        rebuildTableColumnPositions(tableView)
        return tableColumnPositions[tableColumn.identifier] ?? -1
    }

    func invalidateTableColumnPositions() {
        tableColumnPositions.removeAll(keepingCapacity: true)
    }

    private func rebuildTableColumnPositions(_ tableView: NSTableView) {
        tableColumnPositions = Self.positions(of: tableView.tableColumns.map(\.identifier))
    }

    nonisolated static func positions(of identifiers: [NSUserInterfaceItemIdentifier]) -> [NSUserInterfaceItemIdentifier: Int] {
        var positions: [NSUserInterfaceItemIdentifier: Int] = [:]
        positions.reserveCapacity(identifiers.count)
        for (index, identifier) in identifiers.enumerated() where positions[identifier] == nil {
            positions[identifier] = index
        }
        return positions
    }
}
#endif

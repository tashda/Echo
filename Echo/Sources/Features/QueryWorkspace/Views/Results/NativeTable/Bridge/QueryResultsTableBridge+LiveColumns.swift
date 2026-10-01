#if os(macOS)
import AppKit

/// Only the columns near the visible ones get cells.
///
/// A view-based NSTableView builds a cell for every column of every row it shows, whatever the
/// prepared rect says: a 100-column result kept 1,700 live cells for 17 rows, each laid out, drawn
/// and tracked on every scrolled frame, and one screen of scrolling took twelve seconds (traced
/// 2026-10-01). Columns more than half a screen from view get no cell; when a sideways scroll, a
/// column resize or a new size brings one near, the rows on screen fill it in.
/// What the live columns depend on: where the view is, and the table's columns and width.
struct ResultGridLiveColumnsKey: Equatable {
    var minX: CGFloat
    var width: CGFloat
    var columnCount: Int
    var tableWidth: CGFloat
}

extension QueryResultsTableView.Coordinator {
    /// The visible rect widened by half its width on each side, within the table.
    nonisolated static func liveRect(bounds: NSRect, visible: NSRect) -> NSRect {
        guard visible.width > 0 else { return bounds }
        let margin = visible.width / 2
        let minX = max(bounds.minX, visible.minX - margin)
        let maxX = min(bounds.maxX, visible.maxX + margin)
        guard maxX > minX else { return visible }
        return NSRect(x: minX, y: visible.minY, width: maxX - minX, height: visible.height)
    }

    /// The live table columns, worked out again only when the visible rect moves sideways or resizes.
    func liveColumnIndexes(in tableView: NSTableView) -> IndexSet {
        let visible = tableView.visibleRect
        let key = ResultGridLiveColumnsKey(minX: visible.minX, width: visible.width,
                                           columnCount: tableView.numberOfColumns, tableWidth: tableView.bounds.width)
        if key != liveColumnsKey || liveColumns.isEmpty {
            liveColumns = tableView.columnIndexes(in: Self.liveRect(bounds: tableView.bounds, visible: visible))
            liveColumnsKey = key
        }
        return liveColumns
    }

    func isLiveColumn(_ column: Int, in tableView: NSTableView) -> Bool {
        column >= 0 && liveColumnIndexes(in: tableView).contains(column)
    }

    /// Fills in the columns that came near since the last look, for every row that has a view.
    func refreshLiveColumns(_ tableView: NSTableView) {
        let previous = liveColumns
        let current = liveColumnIndexes(in: tableView)
        let arriving = current.subtracting(previous)
        guard !previous.isEmpty, !arriving.isEmpty else { return }
        var rows = IndexSet()
        tableView.enumerateAvailableRowViews { _, row in if row >= 0 { rows.insert(row) } }
        guard !rows.isEmpty else { return }
        tableView.reloadData(forRowIndexes: rows, columnIndexes: arriving)
    }
}
#endif

#if os(iOS)
import UIKit

enum ResultGridMetrics {
    static let indexColumnWidth: CGFloat = 56
    static let rowHeight: CGFloat = 32
    static let headerHeight: CGFloat = 36
    static let cellHorizontalPadding: CGFloat = 10
}

struct SelectedCell: Equatable {
    var row: Int
    var column: Int
}

struct SelectedRegion: Equatable {
    var start: SelectedCell
    var end: SelectedCell

    var normalizedRowRange: ClosedRange<Int> {
        let lower = min(start.row, end.row)
        let upper = max(start.row, end.row)
        return lower...upper
    }

    var normalizedColumnRange: ClosedRange<Int> {
        let lower = min(start.column, end.column)
        let upper = max(start.column, end.column)
        return lower...upper
    }

    func contains(_ cell: SelectedCell) -> Bool {
        normalizedRowRange.contains(cell.row) && normalizedColumnRange.contains(cell.column)
    }

    func containsRow(_ row: Int) -> Bool {
        normalizedRowRange.contains(row)
    }

    func containsColumn(_ column: Int) -> Bool {
        normalizedColumnRange.contains(column)
    }
}

enum DragContext {
    case cells(anchor: SelectedCell)
    case row(anchor: Int)
    case column(anchor: Int)
}

enum SortIndicator {
    case ascending
    case descending
}
#endif

import Foundation

/// Represents the available sort operations for the query results grid.
enum ResultGridSortAction: Equatable {
    case ascending(columnIndex: Int)
    case descending(columnIndex: Int)
    case clear

    var columnIndex: Int? {
        switch self {
        case .ascending(let index), .descending(let index):
            return index
        case .clear:
            return nil
        }
    }
}

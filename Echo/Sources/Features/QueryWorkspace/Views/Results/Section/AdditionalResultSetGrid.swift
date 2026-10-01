import SwiftUI
import AppKit

/// An extra result set (the second SELECT of a batch, and so on) in the same grid as the first,
/// with its own sorting (plan R6).
struct AdditionalResultSetGrid: View {
    @Bindable var state: QueryEditorState
    var databaseType: DatabaseType?

    @State private var sort: SortCriteria?
    @State private var highlightedColumnIndex: Int?
    @State private var rowOrder: [Int] = []

    var body: some View {
        QueryResultsGridView(
            query: state,
            highlightedColumnIndex: highlightedColumnIndex,
            activeSort: sort,
            rowOrder: rowOrder,
            onColumnTap: { index in
                highlightedColumnIndex = highlightedColumnIndex == index ? nil : index
            },
            onSort: applySort,
            onClearColumnHighlight: { highlightedColumnIndex = nil },
            databaseType: databaseType
        )
    }

    private func applySort(_ columnIndex: Int, _ action: ResultGridSortAction) {
        let columns = state.displayedColumns
        switch action {
        case .ascending(let index), .descending(let index):
            guard index < columns.count else { return }
            let ascending = if case .ascending = action { true } else { false }
            sort = SortCriteria(column: columns[index].name, ascending: ascending)
            highlightedColumnIndex = index
            let values = (0..<state.displayedRowCount).map { state.valueForDisplay(row: $0, column: index) }
            rowOrder = Self.sortedRowOrder(values: values, column: columns[index], ascending: ascending)
        case .clear:
            sort = nil
            highlightedColumnIndex = nil
            rowOrder = []
        }
    }

    /// Row indices ordered by one column's values: numbers by value, everything else as text,
    /// NULLs last either way.
    nonisolated static func sortedRowOrder(values: [String?], column: ColumnInfo, ascending: Bool) -> [Int] {
        let isNumeric = ResultGridValueClassifier.kind(for: column, value: "") == .numeric
        return values.indices.sorted { lhs, rhs in
            switch (values[lhs], values[rhs]) {
            case (nil, nil): return lhs < rhs
            case (nil, _): return false
            case (_, nil): return true
            case let (left?, right?):
                let order: ComparisonResult
                if isNumeric, let l = Double(left), let r = Double(right) {
                    order = l < r ? .orderedAscending : (l > r ? .orderedDescending : .orderedSame)
                } else {
                    order = left.localizedStandardCompare(right)
                }
                if order == .orderedSame { return lhs < rhs }
                return ascending ? order == .orderedAscending : order == .orderedDescending
            }
        }
    }
}

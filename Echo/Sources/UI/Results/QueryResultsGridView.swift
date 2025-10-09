import SwiftUI

#if os(macOS)
/// Thin SwiftUI wrapper that allows callers to continue referencing the grid-style
/// results view while the macOS implementation delegates to the AppKit-backed table.
struct QueryResultsGridView: View {
    @ObservedObject var query: QueryEditorState
    var highlightedColumnIndex: Int?
    var activeSort: SortCriteria?
    var rowOrder: [Int]
    var onColumnTap: (Int) -> Void
    var onSort: (Int, ResultGridSortAction) -> Void

    var body: some View {
        QueryResultsTableView(
            query: query,
            highlightedColumnIndex: highlightedColumnIndex,
            activeSort: activeSort,
            rowOrder: rowOrder,
            onColumnTap: onColumnTap,
            onSort: { columnIndex, action in
                let gridAction: ResultGridSortAction
                switch action {
                case .ascending:
                    gridAction = .ascending(columnIndex: columnIndex)
                case .descending:
                    gridAction = .descending(columnIndex: columnIndex)
                case .clear:
                    gridAction = .clear
                }
                onSort(columnIndex, gridAction)
            }
        )
    }
}
#else
/// Placeholder iOS implementation – the macOS build uses the AppKit-backed table view.
struct QueryResultsGridView: View {
    var body: some View {
        Text("Query results grid is only available on macOS.")
    }
}
#endif

import SwiftUI
import AppKit

/// Thin SwiftUI wrapper that allows callers to continue referencing the grid-style
/// results view while the macOS implementation delegates to the AppKit-backed table.
struct QueryResultsGridView: View {
    @Bindable var query: QueryEditorState
    var highlightedColumnIndex: Int?
    var activeSort: SortCriteria?
    var rowOrder: [Int]
    var onColumnTap: (Int) -> Void
    var onSort: (Int, ResultGridSortAction) -> Void
    var onClearColumnHighlight: () -> Void
    var gridState: QueryResultsGridState?

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
            },
            onClearColumnHighlight: onClearColumnHighlight,
            backgroundColor: NSColor(ColorTokens.Background.tertiary),
            onForeignKeyEvent: { _ in },
            onJsonEvent: { _ in },
            persistedState: gridState
        )
    }
}

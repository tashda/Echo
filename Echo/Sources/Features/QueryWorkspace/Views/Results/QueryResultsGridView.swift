import SwiftUI

#if os(macOS)
import AppKit
/// Thin SwiftUI wrapper that allows callers to continue referencing the grid-style
/// results view while the macOS implementation delegates to the AppKit-backed table.
struct QueryResultsGridView: View {
    @ObservedObject var query: QueryEditorState
    var highlightedColumnIndex: Int?
    var activeSort: SortCriteria?
    var rowOrder: [Int]
    var onColumnTap: (Int) -> Void
    var onSort: (Int, ResultGridSortAction) -> Void
    var onClearColumnHighlight: () -> Void
    var gridState: QueryResultsGridState?
    @EnvironmentObject private var themeManager: ThemeManager

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
            foreignKeyDisplayMode: .disabled,
            foreignKeyInspectorBehavior: .respectInspectorVisibility,
            onForeignKeyEvent: { _ in },
            onJsonEvent: { _ in },
            persistedState: gridState
        )
    }
}
#else
struct QueryResultsGridView: View {
    @ObservedObject var query: QueryEditorState
    var highlightedColumnIndex: Int?
    var activeSort: SortCriteria?
    var rowOrder: [Int]
    var onColumnTap: (Int) -> Void
    var onSort: (Int, ResultGridSortAction) -> Void
    var onClearColumnHighlight: () -> Void
    var gridState: QueryResultsGridState?

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    var body: some View {
        QueryResultsGridRepresentable(
            query: query,
            highlightedColumnIndex: highlightedColumnIndex,
            activeSort: activeSort,
            rowOrder: rowOrder,
            onColumnTap: onColumnTap,
            onSort: onSort,
            onClearColumnHighlight: onClearColumnHighlight,
            themeManager: themeManager,
            clipboardHistory: clipboardHistory
        )
        .background(themeManager.resultsGridBackground)
        .modifier(GridBackgroundEffectModifier())
    }
}

private struct GridBackgroundEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .background(.clear)
                .backgroundExtensionEffect()
        } else {
            content
        }
    }
}
#endif

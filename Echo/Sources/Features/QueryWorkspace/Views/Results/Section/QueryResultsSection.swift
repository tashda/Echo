import SwiftUI
import Combine

struct QueryResultsSection: View {
    @Bindable var query: QueryEditorState
    let connection: SavedConnection
    let activeDatabaseName: String?
    let gridState: QueryResultsGridState
    let isResizingResults: Bool
    @Bindable var panelState: BottomPanelState
#if os(macOS)
    let onForeignKeyEvent: (QueryResultsTableView.ForeignKeyEvent) -> Void
    let onJsonEvent: (QueryResultsTableView.JsonCellEvent) -> Void
    let onCellInspect: ((CellValueInspectorContent) -> Void)?
#endif
    @State internal var sortCriteria: SortCriteria?
    @State internal var highlightedColumnIndex: Int?
    @State internal var rowOrder: [Int] = []
    @State internal var lastObservedColumnIDs: [String] = []
#if os(macOS)
    @State internal var jsonInspectorContext: JsonInspectorContext?
#endif

    @Environment(AppearanceStore.self) internal var appearanceStore
    @Environment(ProjectStore.self) internal var projectStore

    internal let statusBarHeight: CGFloat = 24
    internal let statusBarChipSpacing: CGFloat = 12

#if !os(macOS)
    internal let connectionChipMinWidth: CGFloat = 180
    internal let metricChipMinWidth: CGFloat = 82
    internal let timeChipMinWidth: CGFloat = 112
#endif

    internal var selectedTab: ResultTab {
        switch panelState.selectedSegment {
        case .results: return .results
        case .messages: return .messages
        case .executionPlan: return .executionPlan
        case .jsonInspector: return .jsonInspector
        case .liveData: return .results
        }
    }

    enum ResultTab: Hashable {
        case results
        case messages
#if os(macOS)
        case jsonInspector
        case executionPlan
#endif
    }

    var body: some View {
        VStack(spacing: 0) {
            if query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil {
                content
            } else {
                noResultsPlaceholder
            }
        }
        .accessibilityIdentifier("query-results-section")
        .background(ColorTokens.Background.primary)
        .onChange(of: query.resultChangeToken) { _, _ in
            handleResultTokenChange()
        }
        .onChange(of: query.errorMessage) { _, error in
            if error != nil {
                panelState.selectedSegment = .messages
            }
        }
        .onChange(of: query.isExecuting) { _, executing in
            handleExecutionStateChange(isExecuting: executing)
        }
        .task {
            lastObservedColumnIDs = tableColumns.map(\.id)
            if activeSort != nil {
                rebuildRowOrder()
            }
        }
    }

    internal var tableColumns: [ColumnInfo] {
        query.displayedColumns
    }

    internal var activeSort: SortCriteria? {
        guard let sort = sortCriteria,
              tableColumns.contains(where: { $0.name == sort.column }) else {
            return nil
        }
        return sort
    }

}

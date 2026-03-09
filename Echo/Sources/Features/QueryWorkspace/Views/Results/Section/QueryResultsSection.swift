import SwiftUI
import Combine

struct QueryResultsSection: View {
    @ObservedObject var query: QueryEditorState
    let connection: SavedConnection
    let activeDatabaseName: String?
    let gridState: QueryResultsGridState
    let isResizingResults: Bool
#if os(macOS)
    let foreignKeyDisplayMode: ForeignKeyDisplayMode
    let foreignKeyInspectorBehavior: ForeignKeyInspectorBehavior
    let onForeignKeyEvent: (QueryResultsTableView.ForeignKeyEvent) -> Void
    let onJsonEvent: (QueryResultsTableView.JsonCellEvent) -> Void
#endif
    @State internal var selectedTab: ResultTab = .results
    @State internal var sortCriteria: SortCriteria?
    @State internal var highlightedColumnIndex: Int?
    @State internal var rowOrder: [Int] = []
    @State internal var lastObservedColumnIDs: [String] = []
#if os(macOS)
    @State internal var jsonInspectorContext: JsonInspectorContext?
#endif

    @EnvironmentObject private var appearanceStore: AppearanceStore

    internal let statusBarHeight: CGFloat = 24
    internal let statusBarChipSpacing: CGFloat = 12

#if !os(macOS)
    internal let connectionChipMinWidth: CGFloat = 180
    internal let metricChipMinWidth: CGFloat = 82
    internal let timeChipMinWidth: CGFloat = 112
#endif

    enum ResultTab: Hashable {
        case results
        case messages
#if os(macOS)
        case jsonInspector
#endif
    }

    var body: some View {
        VStack(spacing: 0) {
            if query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil {
                toolbar
                Divider().opacity(0.35)
                content
            } else {
                placeholder
            }
            statusBar
        }
        .accessibilityIdentifier("query-results-section")
        .background(ColorTokens.Background.primary)
        .onChange(of: query.resultChangeToken) { _, _ in
            handleResultTokenChange()
        }
        .onChange(of: query.errorMessage) { _, error in
            if error != nil {
                selectedTab = .messages
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

    internal var shouldShowStatusBar: Bool {
        true
    }

#if !os(macOS)
    private var statusBar: some View {
        HStack(spacing: 8) {
            Text(connectionChipText)
            Spacer()
            Text("\(query.rowProgress.displayCount) rows")
            let elapsed = query.isExecuting ? query.currentExecutionTime : (query.lastExecutionTime ?? 0)
            Text(formattedDuration(Int(elapsed.rounded())))
            Text(statusBubbleConfiguration().label)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.primary)
    }
#endif
}

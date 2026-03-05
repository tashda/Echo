import SwiftUI

extension QueryResultsSection {
    var toolbar: some View {
        HStack(spacing: 16) {
            Picker("", selection: $selectedTab) {
                Text("Results").tag(ResultTab.results)
                Text("Messages").tag(ResultTab.messages)
#if os(macOS)
                if jsonInspectorContext != nil {
                    Text("JSON").tag(ResultTab.jsonInspector)
                }
#endif
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            .labelsHidden()

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.xs2)
        .background(ColorTokens.Background.primary)
    }

    @ViewBuilder
    var content: some View {
        Group {
            if query.isExecuting && !hasRows {
                executingView
            } else if let error = query.errorMessage, !hasRows {
                errorView(error)
            } else {
                switch selectedTab {
                case .results:
                    resultsView
                case .messages:
                    messagesView
#if os(macOS)
                case .jsonInspector:
                    jsonInspectorView()
#endif
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(platformBackground)
    }

    var resultsView: some View {
        Group {
            if hasRows {
#if os(macOS)
                QueryResultsTableView(
                    query: query,
                    highlightedColumnIndex: highlightedColumnIndex,
                    activeSort: activeSort,
                    rowOrder: rowOrder,
                    onColumnTap: toggleHighlightedColumn,
                    onSort: { index, action in
                        let column = tableColumns[index]
                        switch action {
                        case .ascending: applySort(column: column, ascending: true)
                        case .descending: applySort(column: column, ascending: false)
                        case .clear:
                            sortCriteria = nil
                            highlightedColumnIndex = nil
                            rebuildRowOrder()
                        }
                    },
                    onClearColumnHighlight: { highlightedColumnIndex = nil },
                    backgroundColor: NSColor(ColorTokens.Background.primary),
                    foreignKeyDisplayMode: foreignKeyDisplayMode,
                    foreignKeyInspectorBehavior: foreignKeyInspectorBehavior,
                    onForeignKeyEvent: onForeignKeyEvent,
                    onJsonEvent: { event in
                        if case .activate(let selection) = event {
                            openJsonInspector(with: selection)
                        }
                        onJsonEvent(event)
                    },
                    persistedState: gridState,
                    isResizing: isResizingResults
                )
#else
                QueryResultsGridView(
                    query: query,
                    rowOrder: rowOrder,
                    sortCriteria: activeSort,
                    onSort: { criteria in
                        sortCriteria = criteria
                        rebuildRowOrder()
                    }
                )
#endif
            } else {
                noRowsReturnedView
            }
        }
    }

    var messagesView: some View {
        ExecutionConsoleView(results: query.results ?? QueryResultSet(columns: [], rows: []))
    }

    var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Results Yet")
                .font(.headline)
            Text("Run a query to see data appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var executingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Executing query...")
                .font(.headline)
            Text("Please wait while we fetch your data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text("Query Failed")
                .font(.headline)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SpacingTokens.xl2)
    }

    var noRowsReturnedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No Rows Returned")
                .font(.headline)
            Text("The query executed successfully but returned no data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var platformBackground: Color { ColorTokens.Background.primary }

    var hasRows: Bool {
        query.displayedRowCount > 0
    }

    var rowCount: Int {
        query.displayedRowCount
    }
}

import SwiftUI

extension QueryResultsSection {
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
                    onForeignKeyEvent: onForeignKeyEvent,
                    onJsonEvent: { event in
                        onJsonEvent(event)
                    },
                    onCellInspect: onCellInspect,
                    persistedState: gridState,
                    isResizing: isResizingResults,
                    alternateRowShading: projectStore.globalSettings.resultsAlternateRowShading,
                    showRowNumbers: projectStore.globalSettings.resultsShowRowNumbers,
                    colorOverrides: projectStore.globalSettings.resultGridColorOverrides
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
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "tablecells")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("No Results Yet")
                .font(TypographyTokens.headline)
            Text("Run a query to see data appear here.")
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var executingView: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
                .controlSize(.large)
            Text("Executing query...")
                .font(TypographyTokens.headline)
            Text("Please wait while we fetch your data.")
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func errorView(_ message: String) -> some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Status.warning)
            Text("Query Failed")
                .font(TypographyTokens.headline)
            Text(message)
                .font(TypographyTokens.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ColorTokens.Text.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SpacingTokens.xl2)
    }

    var noRowsReturnedView: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("No Rows Returned")
                .font(TypographyTokens.headline)
            Text("The query executed successfully but returned no data.")
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.Text.secondary)
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

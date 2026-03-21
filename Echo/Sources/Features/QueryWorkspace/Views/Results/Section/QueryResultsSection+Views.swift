import SwiftUI

extension QueryResultsSection {
    @ViewBuilder
    var content: some View {
        Group {
            if query.isExecuting {
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
                case .executionPlan:
                    executionPlanView
#endif
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(platformBackground)
    }

    var resultsView: some View {
        Group {
            if hasRows || !query.additionalResults.isEmpty {
#if os(macOS)
                if query.additionalResults.isEmpty {
                    primaryResultsTable
                } else {
                    multiResultSetView
                }
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

#if os(macOS)
    private var primaryResultsTable: some View {
        QueryResultsTableView(
            displayedRowCount: query.displayedRowCount,
            resultChangeToken: query.resultChangeToken,
            executionGeneration: query.executionGeneration,
            displayedColumns: query.displayedColumns,
            dataClassification: query.dataClassification,
            isExecuting: query.isExecuting,
            queryStateRef: query,
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
            colorOverrides: projectStore.globalSettings.resultGridColorOverrides,
            isDarkMode: appearanceStore.effectiveColorScheme == .dark
        )
    }

    private var multiResultSetView: some View {
        let allSets = query.allResultSetsForDisplay
        return VStack(spacing: 0) {
            resultSetTabBar(count: allSets.count)

            if query.selectedResultSetIndex == 0 && hasRows {
                primaryResultsTable
            } else if query.selectedResultSetIndex > 0,
                      query.selectedResultSetIndex - 1 < query.additionalResults.count {
                AdditionalResultSetTableView(
                    resultSet: query.additionalResults[query.selectedResultSetIndex - 1],
                    backgroundColor: NSColor(ColorTokens.Background.primary),
                    alternateRowShading: projectStore.globalSettings.resultsAlternateRowShading,
                    showRowNumbers: projectStore.globalSettings.resultsShowRowNumbers
                )
            } else {
                noRowsReturnedView
            }
        }
    }

    private func resultSetTabBar(count: Int) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            ForEach(0..<count, id: \.self) { index in
                let rowCount = resultSetRowCount(at: index)
                Button {
                    query.selectedResultSetIndex = index
                } label: {
                    HStack(spacing: SpacingTokens.xxs) {
                        Text("Result \(index + 1)")
                            .font(TypographyTokens.detail)
                        Text("(\(rowCount))")
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .padding(.horizontal, SpacingTokens.xs)
                    .padding(.vertical, SpacingTokens.xxs)
                    .background(
                        query.selectedResultSetIndex == index
                            ? ColorTokens.Text.primary.opacity(0.08)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 5)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs2)
        .background(ColorTokens.Background.secondary)
    }

    private func resultSetRowCount(at index: Int) -> Int {
        if index == 0 {
            return query.rowProgress.displayCount
        }
        let additionalIndex = index - 1
        guard additionalIndex < query.additionalResults.count else { return 0 }
        return query.additionalResults[additionalIndex].totalRowCount ?? query.additionalResults[additionalIndex].rows.count
    }
#endif

    var noResultsPlaceholder: some View {
        ContentUnavailableView {
            Label("Run a Query", systemImage: "play.rectangle")
        } description: {
            Text("Execute a query to see results, messages, and execution plans.")
        }
    }

    var messagesView: some View {
        ExecutionConsoleView(executionMessages: query.messages) {
            query.messages.removeAll()
        }
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

#if os(macOS)
    var executionPlanView: some View {
        Group {
            if query.isLoadingExecutionPlan {
                VStack(spacing: SpacingTokens.md) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Generating execution plan\u{2026}")
                        .font(TypographyTokens.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let plan = query.executionPlan {
                ExecutionPlanView(plan: plan)
            } else {
                VStack(spacing: SpacingTokens.sm) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(TypographyTokens.hero)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text("No Execution Plan")
                        .font(TypographyTokens.headline)
                    Text("Use the execution plan button to generate a plan for your query.")
                        .font(TypographyTokens.subheadline)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
#endif

    var platformBackground: Color { ColorTokens.Background.primary }

    var hasRows: Bool {
        query.displayedRowCount > 0
    }

    var rowCount: Int {
        query.displayedRowCount
    }
}

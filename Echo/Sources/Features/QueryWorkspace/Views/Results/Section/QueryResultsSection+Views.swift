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
                case .textResults:
                    textResultsView
                case .verticalResults:
                    verticalResultsView
                case .statistics:
                    statisticsView
                case .messages:
                    messagesView
#if os(macOS)
                case .jsonInspector:
                    jsonInspectorView()
                case .executionPlan:
                    executionPlanView
                case .spatial:
                    spatialView
                case .tuning:
                    tuningView
                case .policyManagement:
                    EmptyView()
                case .history:
                    QueryHistoryPanelView(connectionID: connection.id)
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
                VStack(spacing: 0) {
                    resultsToolbar
                    Divider()
                    switch gridState.detailMode {
                    case .table:
                        if query.additionalResults.isEmpty {
                            primaryResultsTable
                        } else {
                            multiResultSetView
                        }
                    case .form:
                        formResultsView
                    case .fieldTypes:
                        fieldTypesResultsView
                    }
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
#if os(macOS)
        .sheet(item: $resultExportViewModel) { viewModel in
            DataExportSheet(viewModel: viewModel) {
                resultExportViewModel = nil
            }
        }
#endif
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
        return VStack(spacing: 0) {
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

    func resultSetTabBar(count: Int) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            ForEach(0..<count, id: \.self) { index in
                let rowCount = resultSetRowCount(at: index)
                Button {
                    query.selectedResultSetIndex = index
                } label: {
                    HStack(spacing: SpacingTokens.xxs) {
                        Text(resultSetTabLabel(at: index))
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

    private func resultSetTabLabel(at index: Int) -> String {
        guard let metadata = query.batchResultMetadata, index < metadata.count else {
            return "Result \(index + 1)"
        }
        let label = metadata[index]
        // Count how many result sets are in this batch
        let batchResultCount = metadata.filter { $0.batchIndex == label.batchIndex }.count
        if batchResultCount > 1 {
            return "Batch \(label.batchIndex + 1): Result \(label.resultSetIndexInBatch + 1)"
        }
        return "Batch \(label.batchIndex + 1)"
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

    var spatialView: some View {
        SpatialResultsView(query: query)
    }

    var tuningView: some View {
        ContentUnavailableView {
            Label("Tuning Advisor", systemImage: "wand.and.stars")
        } description: {
            Text("Missing index recommendations will appear here.")
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

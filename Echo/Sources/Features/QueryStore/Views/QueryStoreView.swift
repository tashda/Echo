import SwiftUI
import SQLServerKit

struct QueryStoreView: View {
    @Bindable internal var viewModel: QueryStoreViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) internal var appState
    @Environment(\.openWindow) private var openWindow

    @State private var selectedSQLContext: SQLPopoutContext?

    var body: some View {
        VStack(spacing: 0) {
            TabSectionToolbar {
                if let options = viewModel.storeOptions {
                    QueryStoreStatusBar(options: options)
                }
            } controls: {
                TabSectionPicker(
                    "Query View",
                    selection: $viewModel.selectedSection,
                    itemCount: QueryStoreViewModel.SelectedSection.allCases.count
                ) {
                    ForEach(QueryStoreViewModel.SelectedSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
            }

            if viewModel.loadingState == .loading || viewModel.loadingState == .idle {
                TabInitializingPlaceholder(
                    icon: "chart.bar.xaxis",
                    title: "Initializing Query Store",
                    subtitle: "Loading query performance data\u{2026}"
                )
            } else if case .error(let message) = viewModel.loadingState {
                ContentUnavailableView {
                    Label("Could not load Query Store", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            } else if let options = viewModel.storeOptions, options.isOff {
                queryStoreDisabledView
            } else {
                contentView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Background.primary)
        .sheet(item: $selectedSQLContext) { context in
            SQLInspectorSheet(context: context) { sql, database in
                environmentState.openFormattedQueryTab(
                    sql: sql,
                    database: database,
                    connectionID: environmentState.sessionGroup.activeSessions.first(where: { $0.id == viewModel.connectionSessionID })?.connection.id ?? UUID(),
                    dialect: .microsoftSQL
                )
            }
        }
        .task {
            await viewModel.loadAll()
        }
        .onAppear {
            Task { await viewModel.refreshOptions() }
        }
        .onChange(of: viewModel.selectedQueryId) { _, newValue in
            pushQueryInspector(queryId: newValue)
        }
    }

    // MARK: - Actions

    internal func popout(_ sql: String) {
        selectedSQLContext = SQLPopoutContext(sql: sql, title: "Query Details", databaseName: viewModel.databaseName, dialect: .microsoftSQL)
    }

    internal func openInQueryWindow(_ sql: String, _ database: String?) {
        let connectionID = environmentState.sessionGroup.activeSessions.first(where: { $0.id == viewModel.connectionSessionID })?.connection.id ?? UUID()
        environmentState.openFormattedQueryTab(sql: sql, database: database, connectionID: connectionID, dialect: .microsoftSQL)
    }

    internal func openDatabaseProperties() {
        let value = environmentState.prepareDatabaseEditorWindow(
            connectionSessionID: viewModel.connectionSessionID,
            databaseName: viewModel.databaseName,
            databaseType: .microsoftSQL
        )
        openWindow(id: DatabaseEditorWindow.sceneID, value: value)
    }

    // MARK: - Inspector

    private func pushQueryInspector(queryId: Int?) {
        guard let queryId else {
            environmentState.dataInspectorContent = nil
            return
        }
        let topQuery = viewModel.topQueries.first(where: { $0.queryId == queryId })
        let regressedQuery = viewModel.regressedQueries.first(where: { $0.queryId == queryId })

        if let top = topQuery {
            let fields: [DatabaseObjectInspectorContent.Field] = [
                .init(label: "Query ID", value: "\(top.queryId)"),
                .init(label: "Executions", value: "\(top.totalExecutions)"),
                .init(label: "Total Duration", value: formatDuration(top.totalDurationUs)),
                .init(label: "Total CPU", value: formatDuration(top.totalCPUUs)),
                .init(label: "Total I/O Reads", value: "\(top.totalIOReads)"),
                .init(label: "Avg Duration", value: formatDuration(top.avgDurationUs)),
                .init(label: "Avg CPU", value: formatDuration(top.avgCPUUs)),
            ]
            environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
                title: "Query \(top.queryId)",
                subtitle: "\(top.totalExecutions) executions \u{2022} \(formatDuration(top.totalDurationUs)) total",
                sqlText: top.queryText,
                fields: fields
            ))
        } else if let reg = regressedQuery {
            let fields: [DatabaseObjectInspectorContent.Field] = [
                .init(label: "Query ID", value: "\(reg.queryId)"),
                .init(label: "Plans", value: "\(reg.planCount)"),
                .init(label: "Best Avg Duration", value: formatDuration(reg.minAvgDurationUs)),
                .init(label: "Worst Avg Duration", value: formatDuration(reg.maxAvgDurationUs)),
                .init(label: "Regression", value: String(format: "%.1fx", reg.regressionRatio)),
            ]
            environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
                title: "Query \(reg.queryId)",
                subtitle: String(format: "%.1fx regression \u{2022} %d plans", reg.regressionRatio, reg.planCount),
                sqlText: reg.queryText,
                fields: fields
            ))
        }
    }

    private func formatDuration(_ microseconds: Double) -> String {
        if microseconds >= 1_000_000 {
            return String(format: "%.2f s", microseconds / 1_000_000)
        } else if microseconds >= 1_000 {
            return String(format: "%.1f ms", microseconds / 1_000)
        } else {
            return String(format: "%.0f \u{00B5}s", microseconds)
        }
    }
}

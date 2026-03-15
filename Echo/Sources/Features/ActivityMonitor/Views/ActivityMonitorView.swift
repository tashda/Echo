import Foundation
import SwiftUI
import SQLServerKit
import PostgresWire

struct ActivityMonitorView: View {
    @ObservedObject var viewModel: ActivityMonitorViewModel
    @EnvironmentObject private var environmentState: EnvironmentState

    // Sorting states
    @State private var processesSortOrder = [KeyPathComparator(\SQLServerProcessInfo.sessionId)]
    @State private var waitsSortOrder = [KeyPathComparator(\SQLServerWaitStatDelta.waitTimeMsDelta, order: .reverse)]
    @State private var ioSortOrder = [KeyPathComparator(\SQLServerFileIOStatDelta.ioStallReadMsDelta, order: .reverse)]
    @State private var queriesSortOrder = [KeyPathComparator(\SQLServerExpensiveQuery.totalWorkerTime, order: .reverse)]

    @State private var pgProcessesSortOrder = [KeyPathComparator(\PostgresProcessInfo.pid)]
    @State private var pgWaitsSortOrder = [KeyPathComparator(\PostgresWaitStatDelta.countDelta, order: .reverse)]
    @State private var pgIOSortOrder = [KeyPathComparator(\PostgresDatabaseStatDelta.xact_commit_delta, order: .reverse)]
    @State private var pgQueriesSortOrder = [KeyPathComparator(\PostgresExpensiveQuery.total_exec_time, order: .reverse)]

    // Pop-out state
    @State private var selectedSQLContext: SQLPopoutContext?

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if viewModel.latestSnapshot == nil {
                loadingView
            } else {
                contentView
            }
        }
        .background(ColorTokens.Background.primary)
        .sheet(item: $selectedSQLContext) { context in
            SQLInspectorPopover(context: context) { sql in
                openInQueryWindow(sql: sql)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
            Text("Initializing Activity Monitor...")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.xl) {
                // 1. Dashboard Overview
                SectionContainer(title: "System Performance", icon: "chart.xyaxis.line") {
                    OverviewGraphsView(viewModel: viewModel)
                        .padding(.top, SpacingTokens.xs)
                }

                // 2. Active Processes
                SectionContainer(title: "Active Processes", icon: "person.2.fill", info: "Real-time view of user and system sessions. Right-click a row to Kill or see Details.") {
                    ProcessesTableView(viewModel: viewModel, sortOrder: processesSortBinding, pgSortOrder: pgProcessesSortBinding) { sql in
                        selectedSQLContext = SQLPopoutContext(sql: sql, title: "Process Query")
                    }
                    .frame(minHeight: viewModel.latestSnapshot?.processes.isEmpty == false ? 350 : 120)
                }

                // 3. Resource & Wait Analysis
                HStack(alignment: .top, spacing: SpacingTokens.xl) {
                    SectionContainer(title: "Top Resource Waits", icon: "hourglass", info: "Cumulative time tasks spent waiting for specific resources.") {
                        ResourceWaitsTableView(viewModel: viewModel, sortOrder: waitsSortBinding, pgSortOrder: pgWaitsSortBinding)
                            .frame(minHeight: 200)
                    }
                    .frame(maxWidth: .infinity)

                    SectionContainer(title: "Data File Activity", icon: "doc.text.fill", info: "Real-time I/O throughput and latency per database/file.") {
                        DataFileIOTableView(viewModel: viewModel, sortOrder: ioSortBinding, pgSortOrder: pgIOSortBinding)
                            .frame(minHeight: 200)
                    }
                    .frame(maxWidth: .infinity)
                }

                // 4. Expensive Queries
                SectionContainer(title: "Expensive Queries", icon: "bolt.horizontal.circle.fill", info: "The most resource-intensive queries recorded since server start.") {
                    ExpensiveQueriesTableView(
                        viewModel: viewModel,
                        sortOrder: queriesSortBinding,
                        pgSortOrder: pgQueriesSortBinding,
                        onOpenExtensionManager: { openExtensionManager() }
                    ) { sql in
                        selectedSQLContext = SQLPopoutContext(sql: sql, title: "Expensive Query")
                    }
                    .frame(minHeight: viewModel.latestSnapshot?.expensiveQueries.isEmpty == false ? 300 : 120)
                }
            }
            .padding(SpacingTokens.lg)
        }
    }

    // MARK: - Sort Bindings

    var processesSortBinding: Binding<[KeyPathComparator<SQLServerProcessInfo>]> {
        Binding(get: { processesSortOrder }, set: { processesSortOrder = $0 })
    }
    var pgProcessesSortBinding: Binding<[KeyPathComparator<PostgresProcessInfo>]> {
        Binding(get: { pgProcessesSortOrder }, set: { pgProcessesSortOrder = $0 })
    }
    var waitsSortBinding: Binding<[KeyPathComparator<SQLServerWaitStatDelta>]> {
        Binding(get: { waitsSortOrder }, set: { waitsSortOrder = $0 })
    }
    var pgWaitsSortBinding: Binding<[KeyPathComparator<PostgresWaitStatDelta>]> {
        Binding(get: { pgWaitsSortOrder }, set: { pgWaitsSortOrder = $0 })
    }
    var ioSortBinding: Binding<[KeyPathComparator<SQLServerFileIOStatDelta>]> {
        Binding(get: { ioSortOrder }, set: { ioSortOrder = $0 })
    }
    var pgIOSortBinding: Binding<[KeyPathComparator<PostgresDatabaseStatDelta>]> {
        Binding(get: { pgIOSortOrder }, set: { pgIOSortOrder = $0 })
    }
    var queriesSortBinding: Binding<[KeyPathComparator<SQLServerExpensiveQuery>]> {
        Binding(get: { queriesSortOrder }, set: { queriesSortOrder = $0 })
    }
    var pgQueriesSortBinding: Binding<[KeyPathComparator<PostgresExpensiveQuery>]> {
        Binding(get: { pgQueriesSortOrder }, set: { pgQueriesSortOrder = $0 })
    }

    func openInQueryWindow(sql: String) {
        if let sessionID = viewModel.latestSnapshotSessionID,
           let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == sessionID }) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        } else {
            environmentState.openQueryTab(presetQuery: sql)
        }
    }

    func openExtensionManager() {
        guard let sessionID = viewModel.latestSnapshotSessionID,
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == sessionID }) else { return }

        let database = session.selectedDatabaseName ?? session.connection.database
        session.addExtensionsManagerTab(databaseName: database)
    }
}

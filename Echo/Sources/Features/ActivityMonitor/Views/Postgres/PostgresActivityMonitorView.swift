import SwiftUI
import PostgresWire

struct PostgresActivityMonitorView: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) private var appState

    @State private var selectedSection: PostgresActivitySection = .sessions

    @State private var sessionsSortOrder = [KeyPathComparator(\PostgresProcessInfo.pid)]
    @State private var locksSortOrder = [KeyPathComparator(\PostgresLockInfo.pid)]
    @State private var dbStatsSortOrder = [KeyPathComparator(\PostgresDatabaseStatDelta.xact_commit_delta, order: .reverse)]
    @State private var queriesSortOrder = [KeyPathComparator(\PostgresExpensiveQuery.total_exec_time, order: .reverse)]
    @State private var replicationSortOrder = [KeyPathComparator(\PostgresReplicationInfo.pid)]

    @State private var selectedSessionIDs: Set<PostgresProcessInfo.ID> = []
    @State private var selectedLockIDs: Set<StickyLockState.StickyLock.ID> = []
    @State private var selectedDBStatIDs: Set<PostgresDatabaseStatDelta.ID> = []
    @State private var selectedOperationIDs: Set<PostgresOperationProgress.ID> = []
    @State private var selectedQueryIDs: Set<PostgresExpensiveQuery.ID> = []

    @State private var selectedSQLContext: SQLPopoutContext?

    enum PostgresActivitySection: String, CaseIterable {
        case sessions = "Sessions"
        case locks = "Locks"
        case database = "Database"
        case operations = "Operations"
        case queries = "Queries"
        case replication = "Replication"
    }

    private var sectionAvailability: [PostgresActivitySection: Bool] {
        guard case .postgres(let snap) = viewModel.latestSnapshot else {
            return Dictionary(uniqueKeysWithValues: PostgresActivitySection.allCases.map { ($0, true) })
        }
        return [
            .sessions: true,
            .locks: true,
            .database: true,
            .operations: true,
            .queries: true,
            .replication: !snap.replicationInfo.isEmpty
        ]
    }

    var body: some View {
        ActivityMonitorTabFrame(
            viewModel: viewModel,
            hasPermission: true,
            hasSnapshot: viewModel.isReady,
            selectedSQLContext: $selectedSQLContext,
            onOpenInQueryWindow: openInQueryWindow
        ) {
            PostgresActivitySectionPicker(
                selection: $selectedSection,
                sectionAvailability: sectionAvailability
            )
            .frame(maxWidth: 480)
        } sparklines: {
            sparklineStrip
        } sectionContent: {
            sectionTable
        }
        .onChange(of: selectedSection) { _, _ in
            environmentState.dataInspectorContent = nil
        }
        .onChange(of: selectedSessionIDs) { _, ids in pushSessionInspector(ids: ids) }
        .onChange(of: selectedLockIDs) { _, ids in pushLockInspector(ids: ids) }
        .onChange(of: selectedDBStatIDs) { _, ids in pushDBStatInspector(ids: ids) }
        .onChange(of: selectedOperationIDs) { _, ids in pushOperationInspector(ids: ids) }
        .onChange(of: selectedQueryIDs) { _, ids in pushQueryInspector(ids: ids) }
    }

    // MARK: - Sparklines

    private var sparklineStrip: some View {
        ActivityMonitorSparklineStrip(metrics: [
            SparklineMetric(label: "Connections", unit: "", color: .blue, maxValue: nil, data: viewModel.connectionCountHistory),
            SparklineMetric(label: "Cache Hit", unit: "%", color: .green, maxValue: 100, data: viewModel.cacheHitHistory),
            SparklineMetric(label: "TX/s", unit: "/s", color: .orange, maxValue: nil, data: viewModel.throughputHistory),
            SparklineMetric(label: "Dead Tuples", unit: "", color: .red, maxValue: nil, data: viewModel.deadTuplesHistory)
        ])
    }

    // MARK: - Section Table

    @ViewBuilder
    private var sectionTable: some View {
        if let snapshot = viewModel.latestSnapshot, case .postgres(let snap) = snapshot {
            switch selectedSection {
            case .sessions:
                PostgresActivitySessions(
                    processes: snap.processes,
                    sortOrder: $sessionsSortOrder,
                    selection: $selectedSessionIDs,
                    onPopout: popout,
                    onKill: kill,
                    canKill: environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)?.permissions?.canManageServerState ?? true,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .locks:
                PostgresActivityLocks(
                    locks: snap.locks,
                    snapshotTime: snap.capturedAt,
                    sortOrder: $locksSortOrder,
                    selection: $selectedLockIDs,
                    onPopout: popout,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .database:
                if let deltas = snap.databaseStatsDelta {
                    PostgresActivityDatabase(
                        stats: deltas,
                        sortOrder: $dbStatsSortOrder,
                        selection: $selectedDBStatIDs,
                        onDoubleClick: { appState.showInfoSidebar.toggle() }
                    )
                } else {
                    ActivitySectionLoadingView(title: "Collecting Database Statistics", subtitle: "Waiting for baseline data\u{2026}")
                }
            case .operations:
                PostgresActivityOperations(
                    operations: snap.operationProgress,
                    selection: $selectedOperationIDs,
                    onCancel: kill,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .queries:
                PostgresActivityQueriesView(
                    snap: snap,
                    sortOrder: $queriesSortOrder,
                    selection: $selectedQueryIDs,
                    onPopout: popout,
                    onOpenExtensionManager: openExtensionManager,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .replication:
                PostgresActivityReplication(info: snap.replicationInfo, sortOrder: $replicationSortOrder)
            }
        } else {
            EmptyTablePlaceholder()
        }
    }

    // MARK: - Actions

    private func popout(_ sql: String) {
        selectedSQLContext = SQLPopoutContext(sql: sql, title: "Query Details")
    }

    private func kill(_ id: Int) {
        Task {
            do {
                try await viewModel.killSession(id: id)
                environmentState.notificationEngine?.post(.processTerminated(pid: id))
            } catch {
                environmentState.notificationEngine?.post(.processTerminateFailed(pid: id, reason: error.localizedDescription))
            }
        }
    }

    private func openInQueryWindow(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        } else {
            environmentState.openQueryTab(presetQuery: sql)
        }
    }

    private func openExtensionManager() {
        guard let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) else { return }
        let database = session.selectedDatabaseName ?? session.connection.database
        environmentState.openExtensionsManagerTab(connectionID: viewModel.connectionID, databaseName: database)
    }
}

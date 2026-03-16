import SwiftUI
import PostgresWire

struct PostgresActivityMonitorView: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @Environment(EnvironmentState.self) private var environmentState
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
        VStack(spacing: 0) {
            ActivityMonitorToolbar(viewModel: viewModel) {
                PostgresActivitySectionPicker(
                    selection: $selectedSection,
                    sectionAvailability: sectionAvailability
                )
                .frame(maxWidth: 480)
            }

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
        .onChange(of: selectedSection) { _, _ in
            environmentState.dataInspectorContent = nil
        }
        .onChange(of: selectedSessionIDs) { _, ids in
            pushSessionInspector(ids: ids)
        }
        .onChange(of: selectedLockIDs) { _, ids in
            pushLockInspector(ids: ids)
        }
        .onChange(of: selectedDBStatIDs) { _, ids in
            pushDBStatInspector(ids: ids)
        }
        .onChange(of: selectedOperationIDs) { _, ids in
            pushOperationInspector(ids: ids)
        }
        .onChange(of: selectedQueryIDs) { _, ids in
            pushQueryInspector(ids: ids)
        }
    }

    private var loadingView: some View {
        TabInitializingPlaceholder(
            icon: "gauge.with.dots.needle.33percent",
            title: "Initializing Activity Monitor",
            subtitle: "Waiting for the first snapshot\u{2026}"
        )
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            sparklineStrip
            Divider()
            sectionTable
        }
    }

    private var sparklineStrip: some View {
        ActivityMonitorSparklineStrip(metrics: [
            SparklineMetric(label: "Connections", unit: "", color: .blue, maxValue: nil, data: viewModel.connectionCountHistory),
            SparklineMetric(label: "Cache Hit", unit: "%", color: .green, maxValue: 100, data: viewModel.cacheHitHistory),
            SparklineMetric(label: "TX/s", unit: "/s", color: .orange, maxValue: nil, data: viewModel.throughputHistory),
            SparklineMetric(label: "Dead Tuples", unit: "", color: .red, maxValue: nil, data: viewModel.deadTuplesHistory)
        ])
    }

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
                    sectionLoadingView(title: "Collecting Database Statistics", subtitle: "Waiting for baseline data\u{2026}")
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

    // MARK: - Inspector

    private func pushSessionInspector(ids: Set<PostgresProcessInfo.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let proc = snap.processes.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        var fields: [ForeignKeyInspectorContent.Field] = [
            .init(label: "PID", value: "\(proc.pid)"),
            .init(label: "User", value: proc.userName ?? "\u{2014}"),
            .init(label: "Database", value: proc.databaseName ?? "\u{2014}"),
            .init(label: "Application", value: proc.applicationName ?? "\u{2014}"),
            .init(label: "Client", value: proc.clientAddress ?? "\u{2014}"),
            .init(label: "State", value: proc.state ?? "\u{2014}"),
            .init(label: "Backend Type", value: proc.backendType ?? "\u{2014}")
        ]
        if let wait = proc.waitEventType {
            fields.append(.init(label: "Wait Event", value: "\(wait): \(proc.waitEvent ?? "")"))
        }
        if let sql = proc.query, !sql.isEmpty {
            fields.append(.init(label: "Query", value: sql))
        }
        environmentState.dataInspectorContent = .foreignKey(ForeignKeyInspectorContent(
            title: "Process \(proc.pid)",
            subtitle: proc.state ?? "unknown",
            fields: fields
        ))
    }

    private func pushLockInspector(ids: Set<StickyLockState.StickyLock.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let key = ids.first else {
            environmentState.dataInspectorContent = nil
            return
        }
        // Match by composite key — try snapshot locks first, fall back to key parsing
        let lock = snap.locks.first(where: {
            StickyLockState.StickyLock.compositeKey(pid: $0.pid, locktype: $0.locktype, relation: $0.relation, mode: $0.mode) == key
        })
        guard let lock else {
            environmentState.dataInspectorContent = nil
            return
        }
        var fields: [ForeignKeyInspectorContent.Field] = [
            .init(label: "PID", value: "\(lock.pid)"),
            .init(label: "Database", value: lock.databaseName ?? "\u{2014}"),
            .init(label: "Lock Type", value: lock.locktype),
            .init(label: "Relation", value: lock.relation ?? "\u{2014}"),
            .init(label: "Mode", value: lock.mode),
            .init(label: "Granted", value: lock.granted ? "Yes" : "Waiting")
        ]
        if let blocking = lock.blockingPid {
            fields.append(.init(label: "Blocked By", value: "PID \(blocking)"))
        }
        if let dur = lock.waitDuration {
            fields.append(.init(label: "Wait Duration", value: String(format: "%.1fs", dur)))
        }
        if let sql = lock.query, !sql.isEmpty {
            fields.append(.init(label: "Query", value: sql))
        }
        environmentState.dataInspectorContent = .foreignKey(ForeignKeyInspectorContent(
            title: "Lock \u{2022} PID \(lock.pid)",
            subtitle: "\(lock.mode) on \(lock.relation ?? lock.locktype)",
            fields: fields
        ))
    }

    private func pushDBStatInspector(ids: Set<PostgresDatabaseStatDelta.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let stat = snap.databaseStatsDelta?.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let cacheHit = stat.cacheHitRatio.map { String(format: "%.1f%%", $0) } ?? "N/A"
        let fields: [ForeignKeyInspectorContent.Field] = [
            .init(label: "Database", value: stat.datname),
            .init(label: "Cache Hit Ratio", value: cacheHit),
            .init(label: "Commits", value: "\(stat.xact_commit_delta)"),
            .init(label: "Rollbacks", value: "\(stat.xact_rollback_delta)"),
            .init(label: "Blocks Read", value: "\(stat.blks_read_delta)"),
            .init(label: "Blocks Hit", value: "\(stat.blks_hit_delta)"),
            .init(label: "Tuples Inserted", value: "\(stat.tup_inserted_delta)"),
            .init(label: "Tuples Updated", value: "\(stat.tup_updated_delta)"),
            .init(label: "Tuples Deleted", value: "\(stat.tup_deleted_delta)"),
            .init(label: "Temp Files", value: "\(stat.temp_files_delta)"),
            .init(label: "Deadlocks", value: "\(stat.deadlocks_delta)")
        ]
        environmentState.dataInspectorContent = .foreignKey(ForeignKeyInspectorContent(
            title: stat.datname,
            subtitle: "Database Statistics (delta)",
            fields: fields
        ))
    }

    private func pushOperationInspector(ids: Set<PostgresOperationProgress.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let op = snap.operationProgress.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        var fields: [ForeignKeyInspectorContent.Field] = [
            .init(label: "PID", value: "\(op.pid)"),
            .init(label: "Operation", value: op.operation),
            .init(label: "Phase", value: op.phase),
            .init(label: "Database", value: op.databaseName ?? "\u{2014}"),
            .init(label: "Object", value: op.relation ?? "\u{2014}")
        ]
        if let pct = op.progressPercent {
            fields.append(.init(label: "Progress", value: String(format: "%.0f%%", pct)))
        }
        environmentState.dataInspectorContent = .foreignKey(ForeignKeyInspectorContent(
            title: "\(op.operation) \u{2022} PID \(op.pid)",
            subtitle: op.phase,
            fields: fields
        ))
    }

    private func pushQueryInspector(ids: Set<PostgresExpensiveQuery.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let query = snap.expensiveQueries.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let fields: [ForeignKeyInspectorContent.Field] = [
            .init(label: "Query", value: query.query),
            .init(label: "Calls", value: "\(query.calls)"),
            .init(label: "Total Time", value: String(format: "%.1f ms", query.total_exec_time)),
            .init(label: "Mean Time", value: String(format: "%.2f ms", query.mean_exec_time)),
            .init(label: "Min Time", value: String(format: "%.2f ms", query.min_exec_time)),
            .init(label: "Max Time", value: String(format: "%.2f ms", query.max_exec_time)),
            .init(label: "Total Rows", value: "\(query.rows)")
        ]
        environmentState.dataInspectorContent = .foreignKey(ForeignKeyInspectorContent(
            title: "Query \(query.queryid ?? 0)",
            subtitle: String(format: "%.1f ms total \u{2022} %d calls", query.total_exec_time, query.calls),
            fields: fields
        ))
    }

    // MARK: - Actions

    private func sectionLoadingView(title: String, subtitle: String) -> some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(subtitle)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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

import SwiftUI
import SQLServerKit

struct MSSQLActivityMonitorView: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    @State private var selectedSection: MSSQLActivitySection = .processes

    @State private var processesSortOrder = [KeyPathComparator(\SQLServerProcessInfo.sessionId)]
    @State private var waitsSortOrder = [KeyPathComparator(\SQLServerWaitStatDelta.waitTimeMsDelta, order: .reverse)]
    @State private var ioSortOrder = [KeyPathComparator(\SQLServerFileIOStatDelta.ioStallReadMsDelta, order: .reverse)]
    @State private var queriesSortOrder = [KeyPathComparator(\SQLServerExpensiveQuery.totalWorkerTime, order: .reverse)]

    @State private var selectedProcessIDs: Set<SQLServerProcessInfo.ID> = []
    @State private var selectedWaitIDs: Set<SQLServerWaitStatDelta.ID> = []
    @State private var selectedIOIDs: Set<SQLServerFileIOStatDelta.ID> = []
    @State private var selectedQueryIDs: Set<SQLServerExpensiveQuery.ID> = []

    @State private var selectedSQLContext: SQLPopoutContext?
    @State private var xeventsPanelState = BottomPanelState.forExtendedEventsTab()

    enum MSSQLActivitySection: String, CaseIterable {
        case processes = "Processes"
        case waits = "Waits"
        case io = "I/O"
        case queries = "Queries"
        case xevents = "XEvents"
    }

    var body: some View {
        VStack(spacing: 0) {
            ActivityMonitorToolbar(viewModel: viewModel) {
                Picker(selection: $selectedSection) {
                    ForEach(MSSQLActivitySection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
            }

            if selectedSection == .xevents {
                xeventsContent
            } else if viewModel.permissionDenied {
                permissionDeniedView
            } else if viewModel.latestSnapshot == nil {
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
        .onChange(of: selectedProcessIDs) { _, ids in pushProcessInspector(ids: ids) }
        .onChange(of: selectedWaitIDs) { _, ids in pushWaitInspector(ids: ids) }
        .onChange(of: selectedIOIDs) { _, ids in pushIOInspector(ids: ids) }
        .onChange(of: selectedQueryIDs) { _, ids in pushQueryInspector(ids: ids) }
    }

    private var permissionDeniedView: some View {
        EmptyStatePlaceholder(
            icon: "lock.shield",
            title: "Insufficient Permissions",
            subtitle: "Activity Monitor requires VIEW SERVER STATE permission on this server. Contact your database administrator to grant access."
        )
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
            SparklineMetric(label: "CPU", unit: "%", color: .blue, maxValue: 100, data: viewModel.cpuHistory),
            SparklineMetric(label: "Waiting", unit: "", color: .orange, maxValue: nil, data: viewModel.waitingTasksHistory),
            SparklineMetric(label: "I/O", unit: " MB/s", color: .purple, maxValue: nil, data: viewModel.ioHistory),
            SparklineMetric(label: "Throughput", unit: "/s", color: .green, maxValue: nil, data: viewModel.throughputHistory)
        ])
    }

    @ViewBuilder
    private var sectionTable: some View {
        if let snapshot = viewModel.latestSnapshot, case .mssql(let snap) = snapshot {
            switch selectedSection {
            case .processes:
                MSSQLActivityProcesses(
                    processes: snap.processes,
                    sortOrder: $processesSortOrder,
                    selection: $selectedProcessIDs,
                    onPopout: popout,
                    onKill: kill,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .waits:
                if snap.waitsDelta == nil {
                    sectionLoadingView(title: "Collecting Wait Statistics", subtitle: "Waiting for baseline data\u{2026}")
                } else {
                MSSQLActivityWaits(
                    waits: snap.waitsDelta ?? [],
                    sortOrder: $waitsSortOrder,
                    selection: $selectedWaitIDs,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
                }
            case .io:
                if snap.fileIODelta == nil {
                    sectionLoadingView(title: "Collecting I/O Statistics", subtitle: "Waiting for baseline data\u{2026}")
                } else {
                    MSSQLActivityFileIO(
                        io: snap.fileIODelta ?? [],
                        sortOrder: $ioSortOrder,
                        selection: $selectedIOIDs,
                        onDoubleClick: { appState.showInfoSidebar.toggle() }
                    )
                }
            case .queries:
                MSSQLActivityQueries(
                    queries: snap.expensiveQueries,
                    sortOrder: $queriesSortOrder,
                    selection: $selectedQueryIDs,
                    onPopout: popout,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .xevents:
                EmptyView() // Handled separately above
            }
        } else {
            EmptyTablePlaceholder()
        }
    }

    @ViewBuilder
    private var xeventsContent: some View {
        if let xeVM = viewModel.extendedEventsVM {
            ExtendedEventsView(viewModel: xeVM, panelState: xeventsPanelState)
        } else {
            EmptyStatePlaceholder(
                icon: "waveform.path.ecg",
                title: "Extended Events",
                subtitle: "Extended Events is not available for this connection"
            )
        }
    }

    // MARK: - Inspector

    private func pushProcessInspector(ids: Set<SQLServerProcessInfo.ID>) {
        guard case .mssql(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let proc = snap.processes.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Session ID", value: "\(proc.sessionId)"),
            .init(label: "Login", value: proc.loginName ?? "\u{2014}"),
            .init(label: "Host", value: proc.hostName ?? "\u{2014}"),
            .init(label: "Program", value: proc.programName ?? "\u{2014}"),
            .init(label: "Client Address", value: proc.clientNetAddress ?? "\u{2014}"),
            .init(label: "Session Status", value: proc.sessionStatus ?? "\u{2014}"),
            .init(label: "CPU (session)", value: "\(proc.sessionCpuTimeMs ?? 0) ms"),
            .init(label: "Memory", value: "\(proc.memoryUsageKB ?? 0) KB"),
            .init(label: "Reads (session)", value: "\(proc.sessionReads ?? 0)"),
            .init(label: "Writes (session)", value: "\(proc.sessionWrites ?? 0)")
        ]
        if let req = proc.request {
            fields.append(.init(label: "Request Status", value: req.status ?? "\u{2014}"))
            fields.append(.init(label: "Command", value: req.command ?? "\u{2014}"))
            if let cpu = req.cpuTimeMs {
                fields.append(.init(label: "CPU (request)", value: "\(cpu) ms"))
            }
            if let elapsed = req.totalElapsedMs {
                fields.append(.init(label: "Elapsed", value: "\(elapsed) ms"))
            }
            if let wait = req.waitType, !wait.isEmpty {
                fields.append(.init(label: "Wait Type", value: wait))
                if let waitMs = req.waitTimeMs {
                    fields.append(.init(label: "Wait Time", value: "\(waitMs) ms"))
                }
            }
            if let blocker = req.blockingSessionId, blocker > 0 {
                fields.append(.init(label: "Blocked By", value: "Session \(blocker)"))
            }
            if let start = req.startTime {
                fields.append(.init(label: "Started", value: start.formatted(date: .omitted, time: .standard)))
            }
            if let pct = req.percentComplete, pct > 0 {
                fields.append(.init(label: "Progress", value: String(format: "%.1f%%", pct)))
            }
        }
        let subtitle: String
        if let blocker = proc.request?.blockingSessionId, blocker > 0 {
            subtitle = "Blocked by SID \(blocker)"
        } else {
            subtitle = proc.sessionStatus ?? "unknown"
        }
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "Session \(proc.sessionId)",
            subtitle: subtitle,
            sqlText: proc.request?.sqlText,
            fields: fields
        ))
    }

    private func pushWaitInspector(ids: Set<SQLServerWaitStatDelta.ID>) {
        guard case .mssql(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let wait = (snap.waitsDelta ?? []).first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let avgWait = wait.waitingTasksCountDelta > 0 ? wait.waitTimeMsDelta / wait.waitingTasksCountDelta : 0
        let signalPct = wait.waitTimeMsDelta > 0 ? Double(wait.signalWaitTimeMsDelta) / Double(wait.waitTimeMsDelta) * 100 : 0
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Wait Type", value: wait.waitType),
            .init(label: "Total Wait Time", value: "\(wait.waitTimeMsDelta) ms"),
            .init(label: "Signal Wait Time", value: "\(wait.signalWaitTimeMsDelta) ms"),
            .init(label: "Resource Wait Time", value: "\(wait.waitTimeMsDelta - wait.signalWaitTimeMsDelta) ms"),
            .init(label: "Signal %", value: String(format: "%.1f%%", signalPct)),
            .init(label: "Waiting Tasks", value: "\(wait.waitingTasksCountDelta)"),
            .init(label: "Avg Wait/Task", value: "\(avgWait) ms")
        ]
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: wait.waitType,
            subtitle: signalPct > 50 ? "CPU contention likely" : "Resource wait",
            fields: fields
        ))
    }

    private func pushIOInspector(ids: Set<SQLServerFileIOStatDelta.ID>) {
        guard case .mssql(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let io = (snap.fileIODelta ?? []).first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let avgReadSize = io.numReadsDelta > 0 ? io.bytesReadDelta / Int64(io.numReadsDelta) : 0
        let avgWriteSize = io.numWritesDelta > 0 ? io.bytesWrittenDelta / Int64(io.numWritesDelta) : 0
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Database", value: io.databaseName ?? "DB \(io.databaseId)"),
            .init(label: "File", value: io.fileName ?? "File \(io.fileId)"),
            .init(label: "Bytes Read", value: ByteCountFormatter.string(fromByteCount: io.bytesReadDelta, countStyle: .binary)),
            .init(label: "Bytes Written", value: ByteCountFormatter.string(fromByteCount: io.bytesWrittenDelta, countStyle: .binary)),
            .init(label: "Read Operations", value: "\(io.numReadsDelta)"),
            .init(label: "Write Operations", value: "\(io.numWritesDelta)"),
            .init(label: "Avg Read Size", value: ByteCountFormatter.string(fromByteCount: avgReadSize, countStyle: .binary)),
            .init(label: "Avg Write Size", value: ByteCountFormatter.string(fromByteCount: avgWriteSize, countStyle: .binary)),
            .init(label: "Read Stall", value: "\(io.ioStallReadMsDelta) ms"),
            .init(label: "Write Stall", value: "\(io.ioStallWriteMsDelta) ms")
        ]
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: io.databaseName ?? "Database \(io.databaseId)",
            subtitle: io.fileName ?? "File \(io.fileId)",
            fields: fields
        ))
    }

    private func pushQueryInspector(ids: Set<SQLServerExpensiveQuery.ID>) {
        guard case .mssql(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let query = snap.expensiveQueries.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let avgWorker = query.executionCount > 0 ? query.totalWorkerTime / Int64(query.executionCount) : 0
        let avgElapsed = query.executionCount > 0 ? query.totalElapsedTime / Int64(query.executionCount) : 0
        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Executions", value: "\(query.executionCount)"),
            .init(label: "Total Worker Time", value: formatMicroseconds(query.totalWorkerTime)),
            .init(label: "Total Elapsed Time", value: formatMicroseconds(query.totalElapsedTime)),
            .init(label: "Avg Worker Time", value: formatMicroseconds(avgWorker)),
            .init(label: "Avg Elapsed Time", value: formatMicroseconds(avgElapsed)),
            .init(label: "Max Worker Time", value: formatMicroseconds(query.maxWorkerTime)),
            .init(label: "Max Elapsed Time", value: formatMicroseconds(query.maxElapsedTime)),
            .init(label: "Logical Reads", value: "\(query.totalLogicalReads)"),
            .init(label: "Logical Writes", value: "\(query.totalLogicalWrites)")
        ]
        if let date = query.lastExecutionTime {
            fields.append(.init(label: "Last Execution", value: date.formatted(date: .abbreviated, time: .standard)))
        }
        if let hash = query.queryHashHex, !hash.isEmpty {
            fields.append(.init(label: "Query Hash", value: hash))
        }
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "Query",
            subtitle: "\(query.executionCount) executions \u{2022} \(formatMicroseconds(query.totalWorkerTime)) total",
            sqlText: query.sqlText,
            fields: fields
        ))
    }

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

    // MARK: - Helpers

    private func formatMicroseconds(_ us: Int64) -> String {
        let ms = us / 1000
        if ms >= 60_000 { return String(format: "%.1f s", Double(ms) / 1000) }
        if ms >= 1000 { return String(format: "%.1f s", Double(ms) / 1000) }
        return "\(ms) ms"
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
}

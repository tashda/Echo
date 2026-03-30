import SwiftUI
import SQLServerKit

struct MSSQLActivityMonitorView: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) private var appState

    @State private var internalSelectedSection: MSSQLActivitySection = .processes
    private var selectedSection: MSSQLActivitySection {
        get {
            if let str = viewModel.selectedSection, let sec = MSSQLActivitySection(rawValue: str) {
                return sec
            }
            return internalSelectedSection
        }
        nonmutating set {
            viewModel.selectedSection = newValue.rawValue
            internalSelectedSection = newValue
        }
    }

    private var selectedSectionBinding: Binding<MSSQLActivitySection> {
        Binding(
            get: { self.selectedSection },
            set: { self.selectedSection = $0 }
        )
    }

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
        case profiler = "Profiler"
    }

    var body: some View {
        if selectedSection == .xevents {
            VStack(spacing: 0) {
                TabSectionToolbar { sectionPicker }
                xeventsContent
            }
        } else if selectedSection == .profiler {
            VStack(spacing: 0) {
                TabSectionToolbar { sectionPicker }
                profilerContent
            }
        } else {
            ActivityMonitorTabFrame(
                viewModel: viewModel,
                hasPermission: !viewModel.permissionDenied,
                hasSnapshot: viewModel.isReady,
                selectedSQLContext: $selectedSQLContext,
                onOpenInQueryWindow: { sql, db in openInQueryWindow(sql: sql, database: db) }
            ) {
                sectionPicker
            } sparklines: {
                sparklineStrip
            } sectionContent: {
                sectionTable
            }
            .onChange(of: viewModel.selectedSection) { _, _ in
                environmentState.dataInspectorContent = nil
            }
            .onChange(of: selectedProcessIDs) { _, ids in pushProcessInspector(ids: ids) }
            .onChange(of: selectedWaitIDs) { _, ids in pushWaitInspector(ids: ids) }
            .onChange(of: selectedIOIDs) { _, ids in pushIOInspector(ids: ids) }
            .onChange(of: selectedQueryIDs) { _, ids in pushQueryInspector(ids: ids) }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        Picker(selection: selectedSectionBinding) {
            ForEach(MSSQLActivitySection.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 400)
    }

    // MARK: - Sparklines

    private var sparklineStrip: some View {
        ActivityMonitorSparklineStrip(metrics: [
            SparklineMetric(label: "CPU", unit: "%", color: .blue, maxValue: 100, data: viewModel.cpuHistory),
            SparklineMetric(label: "Waiting", unit: "", color: .orange, maxValue: nil, data: viewModel.waitingTasksHistory),
            SparklineMetric(label: "I/O", unit: " MB/s", color: .purple, maxValue: nil, data: viewModel.ioHistory),
            SparklineMetric(label: "Throughput", unit: "/s", color: .green, maxValue: nil, data: viewModel.throughputHistory)
        ])
    }

    // MARK: - Section Table

    @ViewBuilder
    private var sectionTable: some View {
        if let snapshot = viewModel.latestSnapshot, case .mssql(let snap) = snapshot {
            switch selectedSection {
            case .processes:
                MSSQLActivityProcesses(
                    processes: snap.processes,
                    sortOrder: $processesSortOrder,
                    selection: $selectedProcessIDs,
                    onPopout: { sql in popout(sql) },
                    onKill: kill,
                    canKill: environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)?.permissions?.canManageServerState ?? true,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .waits:
                if snap.waitsDelta == nil {
                    ActivitySectionLoadingView(title: "Collecting Wait Statistics", subtitle: "Waiting for baseline data\u{2026}")
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
                    ActivitySectionLoadingView(title: "Collecting I/O Statistics", subtitle: "Waiting for baseline data\u{2026}")
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
                    onPopout: { sql in popout(sql) },
                    onOpenInQueryWindow: { sql, db in openInQueryWindow(sql: sql, database: db) },
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .xevents:
                EmptyView()
            case .profiler:
                EmptyView()
            }
        } else {
            EmptyTablePlaceholder()
        }
    }

    // MARK: - XEvents

    @ViewBuilder
    private var xeventsContent: some View {
        if let xeVM = viewModel.extendedEventsVM {
            ExtendedEventsView(
                viewModel: xeVM,
                panelState: xeventsPanelState,
                onPopout: { sql in popout(sql) },
                onDoubleClick: { appState.showInfoSidebar.toggle() }
            )
        } else {
            ContentUnavailableView {
                Label("Extended Events", systemImage: "waveform.path.ecg")
            } description: {
                Text("Extended Events is not available for this connection.")
            }
        }
    }

    // MARK: - Profiler

    @ViewBuilder
    private var profilerContent: some View {
        if let profilerVM = viewModel.profilerVM {
            ProfilerView(
                viewModel: profilerVM,
                onPopout: { sql in popout(sql) },
                onDoubleClick: { appState.showInfoSidebar.toggle() }
            )
        } else {
            ContentUnavailableView {
                Label("SQL Profiler", systemImage: "chart.line.uptrend.xyaxis")
            } description: {
                Text("SQL Profiler is not available for this connection.")
            }
        }
    }

    // MARK: - Actions

    private func popout(_ sql: String, database: String? = nil) {
        selectedSQLContext = SQLPopoutContext(sql: sql, title: "Query Details", databaseName: database, dialect: .microsoftSQL)
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

    private func openInQueryWindow(sql: String, database: String? = nil) {
        Task {
            let formatted = (try? await SQLFormatter.shared.format(sql: sql, dialect: .microsoftSQL)) ?? sql
            if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
                environmentState.openQueryTab(for: session, presetQuery: formatted, database: database)
            } else {
                environmentState.openQueryTab(presetQuery: formatted, database: database)
            }
        }
    }
}

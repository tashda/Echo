import SwiftUI
import SQLServerKit

struct MSSQLActivityMonitorView: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @Environment(EnvironmentState.self) var environmentState
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
        if selectedSection == .xevents {
            VStack(spacing: 0) {
                TabSectionToolbar { sectionPicker }
                xeventsContent
            }
        } else {
            ActivityMonitorTabFrame(
                viewModel: viewModel,
                hasPermission: !viewModel.permissionDenied,
                hasSnapshot: viewModel.isReady,
                selectedSQLContext: $selectedSQLContext,
                onOpenInQueryWindow: openInQueryWindow
            ) {
                sectionPicker
            } sparklines: {
                sparklineStrip
            } sectionContent: {
                sectionTable
            }
            .onChange(of: selectedSection) { _, _ in
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
                    onPopout: popout,
                    onKill: kill,
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
                    onPopout: popout,
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                )
            case .xevents:
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
            ExtendedEventsView(viewModel: xeVM, panelState: xeventsPanelState)
        } else {
            ContentUnavailableView {
                Label("Extended Events", systemImage: "waveform.path.ecg")
            } description: {
                Text("Extended Events is not available for this connection.")
            }
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
}

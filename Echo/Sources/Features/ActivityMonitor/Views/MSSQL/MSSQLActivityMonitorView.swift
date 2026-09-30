import SwiftUI
import SQLServerKit

struct MSSQLActivityMonitorView: View {
    @Bindable internal var viewModel: ActivityMonitorViewModel
    @Environment(EnvironmentState.self) internal var environmentState
    @Environment(AppState.self) internal var appState

    @State private var internalSelectedSection: MSSQLActivitySection = .processes
    internal var selectedSection: MSSQLActivitySection {
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

    @State internal var processesSortOrder = [KeyPathComparator(\SQLServerProcessInfo.sessionId)]
    @State internal var waitsSortOrder = [KeyPathComparator(\SQLServerWaitStatDelta.waitTimeMsDelta, order: .reverse)]
    @State internal var ioSortOrder = [KeyPathComparator(\SQLServerFileIOStatDelta.ioStallReadMsDelta, order: .reverse)]
    @State internal var queriesSortOrder = [KeyPathComparator(\SQLServerExpensiveQuery.totalWorkerTime, order: .reverse)]

    @State internal var selectedProcessIDs: Set<SQLServerProcessInfo.ID> = []
    @State internal var selectedWaitIDs: Set<SQLServerWaitStatDelta.ID> = []
    @State internal var selectedIOIDs: Set<SQLServerFileIOStatDelta.ID> = []
    @State internal var selectedQueryIDs: Set<SQLServerExpensiveQuery.ID> = []

    @State private var selectedSQLContext: SQLPopoutContext?
    @State internal var xeventsPanelState = BottomPanelState.forExtendedEventsTab()

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
            xeventsContent
                .tabContentFrame()
        } else if selectedSection == .profiler {
            profilerContent
                .tabContentFrame()
        } else {
            ActivityMonitorTabFrame(
                viewModel: viewModel,
                hasPermission: !viewModel.permissionDenied,
                hasSnapshot: viewModel.isReady,
                selectedSQLContext: $selectedSQLContext,
                onOpenInQueryWindow: { sql, db in environmentState.openFormattedQueryTab(sql: sql, database: db, connectionID: viewModel.connectionID, dialect: .microsoftSQL) }
            ) {
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

    // MARK: - Sparklines

    private var sparklineStrip: some View {
        ActivityMonitorSparklineStrip(metrics: [
            SparklineMetric(label: "CPU", unit: "%", color: .blue, maxValue: 100, data: viewModel.cpuHistory),
            SparklineMetric(label: "Waiting", unit: "", color: .orange, maxValue: nil, data: viewModel.waitingTasksHistory),
            SparklineMetric(label: "I/O", unit: " MB/s", color: .purple, maxValue: nil, data: viewModel.ioHistory),
            SparklineMetric(label: "Throughput", unit: "/s", color: .green, maxValue: nil, data: viewModel.throughputHistory)
        ])
    }

    // MARK: - Actions

    internal func popout(_ sql: String, database: String? = nil) {
        selectedSQLContext = SQLPopoutContext(sql: sql, title: "Query Details", databaseName: database, dialect: .microsoftSQL)
    }

    internal func kill(_ id: Int) {
        Task {
            do {
                try await viewModel.killSession(id: id)
                environmentState.notificationEngine?.post(.processTerminated(pid: id))
            } catch {
                environmentState.notificationEngine?.post(.processTerminateFailed(pid: id, reason: error.localizedDescription))
            }
        }
    }

}

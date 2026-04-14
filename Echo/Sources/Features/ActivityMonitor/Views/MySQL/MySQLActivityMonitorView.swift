import SwiftUI

struct MySQLActivityMonitorView: View {
    enum MySQLActivitySection: String, CaseIterable {
        case overview = "Overview"
        case processes = "Processes"
        case queries = "Queries"
        case waits = "Waits"
        case io = "I/O"
        case innodb = "InnoDB"
        case replication = "Repl"
        case reports = "Reports"
        case variables = "Variables"
    }

    @Bindable var viewModel: ActivityMonitorViewModel
    @Environment(EnvironmentState.self) var environmentState
    @State var selectedSQLContext: SQLPopoutContext?
    @State var selectedProcessIDs: Set<Int> = []
    @State var selectedSection: MySQLActivitySection = .overview

    var body: some View {
        ActivityMonitorTabFrame(
            viewModel: viewModel,
            hasPermission: !viewModel.permissionDenied,
            hasSnapshot: viewModel.isReady,
            selectedSQLContext: $selectedSQLContext,
            onOpenInQueryWindow: { sql, db in
                environmentState.openFormattedQueryTab(sql: sql, database: db, connectionID: viewModel.connectionID, dialect: .mysql)
            }
        ) {
            MySQLActivitySectionPicker(selection: $selectedSection)
                .frame(maxWidth: 520)
        } sparklines: {
            ActivityMonitorSparklineStrip(metrics: sparklineMetrics)
        } sectionContent: {
            sectionContentView
        }
        .onChange(of: selectedSection) {
            environmentState.dataInspectorContent = nil
            selectedProcessIDs = []
        }
        .onChange(of: selectedProcessIDs) { _, ids in
            pushProcessInspector(ids: ids)
        }
    }

    var mysqlSnapshot: MySQLActivitySnapshot? {
        guard let snapshot = viewModel.latestSnapshot, case .mysql(let snap) = snapshot else {
            return nil
        }
        return snap
    }

    private var sparklineMetrics: [SparklineMetric] {
        [
            SparklineMetric(
                label: "Connections",
                unit: "",
                color: .blue,
                maxValue: nil,
                data: viewModel.connectionCountHistory
            ),
            SparklineMetric(
                label: "Queries/s",
                unit: "/s",
                color: .orange,
                maxValue: nil,
                data: viewModel.throughputHistory
            ),
            SparklineMetric(
                label: "Incoming",
                unit: "KB/s",
                color: .teal,
                maxValue: nil,
                data: viewModel.ioHistory
            ),
            SparklineMetric(
                label: "Buffer Pool",
                unit: "%",
                color: .green,
                maxValue: 100,
                data: viewModel.cacheHitHistory
            )
        ]
    }
}

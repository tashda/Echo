import SwiftUI

struct MySQLActivityMonitorView: View {
    enum Section: String, CaseIterable {
        case overview = "Overview"
        case reports = "Reports"
        case variables = "Variables"
        case processes = "Processes"
    }

    @Bindable var viewModel: ActivityMonitorViewModel
    @State var selectedSQLContext: SQLPopoutContext?
    @State var selectedProcessIDs: Set<Int> = []
    @State var selectedSection: Section = .overview

    var body: some View {
        ActivityMonitorTabFrame(
            viewModel: viewModel,
            hasPermission: !viewModel.permissionDenied,
            hasSnapshot: viewModel.isReady,
            selectedSQLContext: $selectedSQLContext,
            onOpenInQueryWindow: { _ in }
        ) {
            Picker("", selection: $selectedSection) {
                ForEach(Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
        } sparklines: {
            ActivityMonitorSparklineStrip(metrics: sparklineMetrics)
        } sectionContent: {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    sectionContentView
                }
                .padding(SpacingTokens.md)
            }
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

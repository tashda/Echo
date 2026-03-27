import SwiftUI

struct MySQLActivityMonitorView: View {
    enum Section: String, CaseIterable {
        case overview = "Overview"
        case reports = "Reports"
        case variables = "Variables"
        case processes = "Processes"
    }

    @Bindable var viewModel: ActivityMonitorViewModel
    @State private var selectedSQLContext: SQLPopoutContext?
    @State private var selectedProcessIDs: Set<Int> = []
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

    @ViewBuilder
    var processListContent: some View {
        if let snap = mysqlSnapshot {
            if snap.processes.isEmpty {
                ContentUnavailableView {
                    Label("No Active Processes", systemImage: "person.3")
                } description: {
                    Text("No active connections found.")
                }
            } else {
                processTable(snap.processes)
            }
        } else {
            ActivitySectionLoadingView(title: "Process List", subtitle: "Loading process list\u{2026}")
        }
    }

    private func processTable(_ processes: [MySQLProcessInfo]) -> some View {
        Table(processes, selection: $selectedProcessIDs) {
            TableColumn("ID") { process in
                Text("\(process.id)")
                    .font(TypographyTokens.Table.sql)
            }
            .width(min: 40, ideal: 60)

            TableColumn("User") { process in
                Text(process.user)
                    .font(TypographyTokens.detail)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Host") { process in
                Text(process.host)
                    .font(TypographyTokens.detail)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Database") { process in
                Text(process.database ?? "")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(process.database != nil ? ColorTokens.Text.primary : ColorTokens.Text.placeholder)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Command") { process in
                Text(process.command)
                    .font(TypographyTokens.detail)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Time (s)") { process in
                Text("\(process.time)")
                    .font(TypographyTokens.Table.sql)
                    .foregroundStyle(process.time > 30 ? ColorTokens.Status.warning : ColorTokens.Text.primary)
            }
            .width(min: 50, ideal: 60)

            TableColumn("State") { process in
                Text(process.state ?? "")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Query") { process in
                Text(process.info ?? "")
                    .font(TypographyTokens.Table.sql)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 100, ideal: 300)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: MySQLProcessInfo.ID.self) { selection in
            if let processID = selection.first {
                Button("Kill Process \(processID)") {
                    Task { try? await viewModel.killSession(id: processID) }
                }
            }
        } primaryAction: { _ in }
    }
}

import SwiftUI
import SQLServerKit

struct ProfilerView: View {
    @Bindable var viewModel: ProfilerViewModel
    let onPopout: (String) -> Void
    var onDoubleClick: (() -> Void)?

    @State private var showTemplateSheet = false
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\SQLServerProfilerEvent.timestamp, order: .reverse)]
    @Environment(ProjectStore.self) private var projectStore

    private var sortedEvents: [SQLServerProfilerEvent] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let events = query.isEmpty ? viewModel.events : viewModel.events.filter { event in
            [event.eventName, event.textData, event.databaseName, event.loginName]
                .contains { $0?.localizedCaseInsensitiveContains(query) ?? false }
        }
        return events.sorted(using: sortOrder)
    }

    var body: some View {
        // A Monitor (round 37.4): the figures as tiles, then the live table on its card; the
        // picker and filter on the header line (37.2), the buttons in the window toolbar (37.5).
        VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
            ActivityMonitorSparklineStrip(metrics: ProfilerFigures.metrics(for: viewModel.events))
            eventContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTokens.Background.primary)
                .workspaceCard()
        }
        .tabContentFrame()
        .toolTabHeaderControls { headerControls }
        // Round 37.5: Start Trace is the special button; Events, Clear and Export the group.
        .tabToolbar(
            special: TabToolbarItem(id: "trace", title: "Start Trace", symbol: "play.fill", isRunning: viewModel.isRunning,
                                    runningTitle: "Stop Trace") { [viewModel] in viewModel.toggleTracing() },
            groups: [[
                TabToolbarItem(id: "events", title: "Choose trace events (\(viewModel.selectedTraceEvents.count))", symbol: "list.bullet",
                               isDisabled: viewModel.isRunning) { showTemplateSheet = true },
                TabToolbarItem(id: "clear", title: "Clear captured trace events", symbol: "trash",
                               isDisabled: viewModel.events.isEmpty) { [viewModel] in viewModel.clear() },
                TabToolbarItem(id: "export", title: "Export captured trace events", symbol: "square.and.arrow.up",
                               isDisabled: viewModel.events.isEmpty) { exportTrace() },
            ]]
        )
        .toolTabHeaderDetail(viewModel.events.isEmpty ? nil : "\(viewModel.events.count.formatted()) events")
        .task { await viewModel.loadDatabases() }
        .sheet(isPresented: $showTemplateSheet) {
            ProfilerEventPickerSheet(
                selectedEvents: $viewModel.selectedTraceEvents,
                onDismiss: { showTemplateSheet = false }
            )
        }
    }

    private var headerControls: some View {
        Group {
            ToolTabPickerPill(
                title: "Database", systemImage: "cylinder",
                selection: Binding(get: { viewModel.targetDatabase ?? "" },
                                   set: { viewModel.targetDatabase = $0.isEmpty ? nil : $0 }),
                options: [""] + viewModel.databaseList,
                label: { $0.isEmpty ? "All Databases" : $0 }
            )
            .disabled(viewModel.isRunning)
            ToolTabSearchField(prompt: "Filter events", text: $searchText)
        }
    }

    @ViewBuilder
    private var eventContent: some View {
        if sortedEvents.isEmpty {
            TabContentUnavailableView(
                viewModel.isRunning ? "Waiting for Trace Events" : "No Trace Events",
                systemImage: "chart.line.uptrend.xyaxis"
            ) {
                Text(viewModel.isRunning ? "Trace events will appear here as SQL Server emits them." : "Start a trace to capture SQL Server activity.")
            } actions: {
                if !viewModel.isRunning {
                    Button("Start Trace") { viewModel.toggleTracing() }
                        .buttonStyle(.bordered)
                }
            }
        } else {
            eventTable
        }
    }

    private var eventTable: some View {
        Table(sortedEvents, selection: $viewModel.selectedEventID, sortOrder: $sortOrder) {
            TableColumn("Time", value: \.sortableTimestamp) { event in
                if let date = event.timestamp {
                    Text(date, style: .time)
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 100)

            TableColumn("Event", value: \.eventName) { event in
                Text(event.eventName)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Duration (ms)", value: \.sortableDuration) { event in
                Text(event.duration.map { "\($0)" } ?? "—")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.accent)
            }
            .width(80)
            
            TableColumn("CPU", value: \.sortableCPU) { event in
                Text(event.cpu.map { "\($0)" } ?? "—")
                    .font(TypographyTokens.Table.numeric)
            }
            .width(60)
            
            TableColumn("Reads", value: \.sortableReads) { event in
                Text(event.reads.map { "\($0)" } ?? "—")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(60)
            
            TableColumn("SQL Text", value: \.sortableText) { event in
                SQLQueryCell(sql: event.textData ?? "", onPopout: onPopout)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: SQLServerProfilerEvent.ID.self) { selection in
            if let id = selection.first, let event = viewModel.events.first(where: { $0.id == id }) {
                Button {
                    if let sql = event.textData { onPopout(sql) }
                } label: {
                    Label("Details", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .disabled(event.textData == nil)
            }
        } primaryAction: { _ in
            onDoubleClick?()
        }
    }
}

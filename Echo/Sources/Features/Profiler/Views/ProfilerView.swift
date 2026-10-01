import SwiftUI
import SQLServerKit

struct ProfilerView: View {
    @Bindable var viewModel: ProfilerViewModel
    let onPopout: (String) -> Void
    var onDoubleClick: (() -> Void)?

    @State private var showTemplateSheet = false
    @State private var sortOrder = [KeyPathComparator(\SQLServerProfilerEvent.timestamp, order: .reverse)]

    private var sortedEvents: [SQLServerProfilerEvent] {
        viewModel.events.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            eventContent
        }
        .background(ColorTokens.Background.primary)
        .tabContentFrame()
        .task { await viewModel.loadDatabases() }
        .sheet(isPresented: $showTemplateSheet) {
            ProfilerEventPickerSheet(
                selectedEvents: $viewModel.selectedTraceEvents,
                onDismiss: { showTemplateSheet = false }
            )
        }
    }

    private var toolbar: some View {
        TabSectionToolbar {
            Button {
                viewModel.toggleTracing()
            } label: {
                Label(
                    viewModel.isRunning ? "Stop Trace" : "Start Trace",
                    systemImage: viewModel.isRunning ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(viewModel.isRunning ? ColorTokens.Status.error : ColorTokens.accent)
            
            Button {
                viewModel.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(viewModel.events.isEmpty)
            .help("Clear captured trace events")

            Picker("Database", selection: Binding(
                get: { viewModel.targetDatabase ?? "" },
                set: { viewModel.targetDatabase = $0.isEmpty ? nil : $0 }
            )) {
                Text("All Databases").tag("")
                ForEach(viewModel.databaseList, id: \.self) { db in
                    Text(db).tag(db)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
            .disabled(viewModel.isRunning)

            Button {
                showTemplateSheet = true
            } label: {
                Label("Events (\(viewModel.selectedTraceEvents.count))", systemImage: "list.bullet")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(viewModel.isRunning)
            .help("Choose trace events")

            Button {
                exportTrace()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(viewModel.events.isEmpty)
            .help("Export captured trace events")
        } controls: {
            if viewModel.isRunning {
                Label("Tracing", systemImage: "record.circle")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.success)
            }
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

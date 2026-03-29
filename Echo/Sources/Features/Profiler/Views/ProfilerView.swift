import SwiftUI
import SQLServerKit
import AppKit
import UniformTypeIdentifiers

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
            
            eventTable
        }
        .background(ColorTokens.Background.primary)
        .task { await viewModel.loadDatabases() }
        .sheet(isPresented: $showTemplateSheet) {
            ProfilerEventPickerSheet(
                selectedEvents: $viewModel.selectedTraceEvents,
                onDismiss: { showTemplateSheet = false }
            )
        }
    }

    private func exportTrace() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.nameFieldStringValue = "profiler_trace.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let events = viewModel.events
        let isCSV = url.pathExtension.lowercased() == "csv"

        do {
            if isCSV {
                var csv = "timestamp,event,database,login,duration_ms,cpu,reads,writes,spid,sql_text\n"
                let fmt = ISO8601DateFormatter()
                for e in events {
                    let ts = e.timestamp.map { fmt.string(from: $0) } ?? ""
                    let sql = (e.textData ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                    csv += "\"\(ts)\",\"\(e.eventName)\",\"\(e.databaseName ?? "")\",\"\(e.loginName ?? "")\",\(e.duration ?? 0),\(e.cpu ?? 0),\(e.reads ?? 0),\(e.writes ?? 0),\(e.spid ?? 0),\"\(sql)\"\n"
                }
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } else {
                let jsonEvents: [[String: Any]] = events.map { e in
                    var dict: [String: Any] = ["event_name": e.eventName]
                    if let ts = e.timestamp { dict["timestamp"] = ISO8601DateFormatter().string(from: ts) }
                    if let t = e.textData { dict["sql_text"] = t }
                    if let d = e.databaseName { dict["database"] = d }
                    if let l = e.loginName { dict["login"] = l }
                    if let dur = e.duration { dict["duration_ms"] = dur }
                    if let c = e.cpu { dict["cpu"] = c }
                    if let r = e.reads { dict["reads"] = r }
                    if let w = e.writes { dict["writes"] = w }
                    if let s = e.spid { dict["spid"] = s }
                    return dict
                }
                let data = try JSONSerialization.data(withJSONObject: jsonEvents, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: url)
            }
        } catch { }
    }
    
    private var toolbar: some View {
        HStack {
            Button {
                viewModel.toggleTracing()
            } label: {
                Label(
                    viewModel.isRunning ? "Stop Trace" : "Start Trace",
                    systemImage: viewModel.isRunning ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(.bordered)
            .tint(viewModel.isRunning ? .red : .accentColor)
            
            Button {
                viewModel.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(viewModel.events.isEmpty)

            Divider().frame(height: 16)

            Picker("Database", selection: Binding(
                get: { viewModel.targetDatabase ?? "" },
                set: { viewModel.targetDatabase = $0.isEmpty ? nil : $0 }
            )) {
                Text("All Databases").tag("")
                ForEach(viewModel.databaseList, id: \.self) { db in
                    Text(db).tag(db)
                }
            }
            .frame(width: 180)
            .disabled(viewModel.isRunning)

            Divider().frame(height: 16)

            Button {
                showTemplateSheet = true
            } label: {
                Label("Events (\(viewModel.selectedTraceEvents.count))", systemImage: "list.bullet")
            }
            .disabled(viewModel.isRunning)

            Button {
                exportTrace()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.events.isEmpty)

            Spacer()

            if viewModel.isRunning {
                ProgressView()
                    .controlSize(.small)
                Text("Tracing active...")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Background.secondary)
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
                Text(event.duration.map { "\($0)" } ?? "")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.accent)
            }
            .width(80)
            
            TableColumn("CPU", value: \.sortableCPU) { event in
                Text(event.cpu.map { "\($0)" } ?? "")
                    .font(TypographyTokens.Table.numeric)
            }
            .width(60)
            
            TableColumn("Reads", value: \.sortableReads) { event in
                Text(event.reads.map { "\($0)" } ?? "")
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

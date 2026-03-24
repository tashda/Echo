import SwiftUI
import SQLServerKit
import AppKit
import UniformTypeIdentifiers

struct ProfilerView: View {
    @Bindable var viewModel: ProfilerViewModel

    @State private var showTemplateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            
            VSplitView {
                eventTable
                    .frame(minHeight: 200)
                
                eventDetailView
                    .frame(minHeight: 100)
            }
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
        Table(viewModel.events, selection: $viewModel.selectedEventID) {
            TableColumn("Event") { event in
                Text(event.eventName)
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Duration (ms)") { event in
                Text(event.duration.map { "\($0)" } ?? "")
            }
            .width(80)
            
            TableColumn("CPU") { event in
                Text(event.cpu.map { "\($0)" } ?? "")
            }
            .width(60)
            
            TableColumn("Reads") { event in
                Text(event.reads.map { "\($0)" } ?? "")
            }
            .width(60)
            
            TableColumn("Text") { event in
                Text(event.textData ?? "")
                    .lineLimit(1)
            }
        }
    }
    
    private var eventDetailView: some View {
        ScrollView {
            if let event = viewModel.selectedEvent {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    if let sql = event.textData {
                        GroupBox("SQL Text") {
                            Text(sql)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .padding(SpacingTokens.xs)
                        }
                    }
                    
                    LazyVGrid(columns: [GridItem(.fixed(100)), GridItem(.flexible())], alignment: .leading) {
                        detailRow("Login", event.loginName)
                        detailRow("Database", event.databaseName)
                        detailRow("SPID", event.spid.map { "\($0)" })
                        detailRow("Reads", event.reads.map { "\($0)" })
                        detailRow("Writes", event.writes.map { "\($0)" })
                    }
                }
                .padding(SpacingTokens.md)
            } else {
                ContentUnavailableView("No Event Selected", systemImage: "info.circle")
            }
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.Background.secondary)
    }
    
    private func detailRow(_ label: String, _ value: String?) -> some View {
        Group {
            Text(label + ":")
                .foregroundStyle(.secondary)
            Text(value ?? "-")
        }
    }
}

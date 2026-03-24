import SwiftUI
import SQLServerKit

struct ProfilerView: View {
    @Bindable var viewModel: ProfilerViewModel
    
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

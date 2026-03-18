import SwiftUI
import SQLServerKit

struct ExtendedEventsDataView: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    
    @State private var selection: Set<SQLServerXEEventData.ID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.selectedSessionName == nil {
                noSessionPlaceholder
            } else if viewModel.eventDataLoadingState == .loading && viewModel.eventData.isEmpty {
                loadingPlaceholder
            } else if case .error(let message) = viewModel.eventDataLoadingState {
                errorPlaceholder(message)
            } else if viewModel.eventData.isEmpty {
                emptyPlaceholder
            } else {
                eventTable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Background.primary)
        .task(id: viewModel.selectedSessionName) {
            if viewModel.selectedSessionName != nil {
                await viewModel.loadEventData()
            }
        }
    }

    // MARK: - Event Table

    private var eventTable: some View {
        Table(viewModel.eventData, selection: $selection) {
            TableColumn("Timestamp") { event in
                Text(formattedTimestamp(event.timestamp))
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(180)
            
            TableColumn("Event") { event in
                Text(event.eventName)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.primary)
            }
            .width(200)
            
            TableColumn("Details") { event in
                Text(summaryFields(event.fields))
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
        }
        .contextMenu(forSelectionType: SQLServerXEEventData.ID.self) { ids in
            Button {
                Task { await viewModel.loadEventData() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            
            if let id = ids.first, let event = viewModel.eventData.first(where: { $0.id == id }) {
                Button {
                    appState.showInfoSidebar.toggle()
                } label: {
                    Label("View Details", systemImage: "info.circle")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                viewModel.eventData = []
            } label: {
                Label("Clear List", systemImage: "xmark.circle")
            }
        } primaryAction: { _ in
            if let id = selection.first, let event = viewModel.eventData.first(where: { $0.id == id }) {
                pushEventInspector(event, toggle: true)
            }
        }
        .onChange(of: selection) { _, newSelection in
            if let id = newSelection.first, let event = viewModel.eventData.first(where: { $0.id == id }) {
                pushEventInspector(event, toggle: false)
            }
        }
    }

    private func pushEventInspector(_ event: SQLServerXEEventData, toggle: Bool) {
        let fields: [DatabaseObjectInspectorContent.Field] = event.fields.sorted(by: { $0.key < $1.key }).map { 
            .init(label: $0.key, value: $0.value)
        }
        
        let content = DatabaseObjectInspectorContent(
            title: event.eventName,
            subtitle: formattedTimestamp(event.timestamp),
            fields: fields
        )
        
        if toggle {
            environmentState.toggleDataInspector(content: .databaseObject(content), title: "XE:\(event.id)", appState: appState)
        } else {
            environmentState.dataInspectorContent = .databaseObject(content)
        }
    }

    // MARK: - Formatting

    private func formattedTimestamp(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func summaryFields(_ fields: [String: String]) -> String {
        let priority = ["sql_text", "database_name", "duration", "username", "statement"]
        var parts: [String] = []
        for key in priority {
            if let value = fields[key], !value.isEmpty {
                let truncated = value.count > 80 ? String(value.prefix(80)) + "..." : value
                parts.append("\(key): \(truncated)")
            }
        }
        if parts.isEmpty {
            let remaining = fields.prefix(3).map { "\($0.key): \($0.value)" }
            parts = Array(remaining)
        }
        return parts.joined(separator: " | ")
    }

    // MARK: - Placeholders

    private var noSessionPlaceholder: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Select a running session to view captured events")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
            Text("Loading event data...")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorPlaceholder(_ message: String) -> some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(ColorTokens.Status.warning)
            Text(message)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("No events captured yet")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("The session's ring buffer has no data. Wait for events to occur, then refresh.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

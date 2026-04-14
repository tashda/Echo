import SwiftUI
import SQLServerKit

struct ExtendedEventsDataView: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    let onPopout: ((String) -> Void)?
    var onDoubleClick: (() -> Void)?
    
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    
    @State private var selection: Set<SQLServerXEEventData.ID> = []
    @State private var eventSortOrder: [KeyPathComparator<SQLServerXEEventData>] = [KeyPathComparator(\.sortableTimestamp, order: .reverse)]
    @State private var searchText = ""

    init(viewModel: ExtendedEventsViewModel, onPopout: ((String) -> Void)? = nil, onDoubleClick: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onPopout = onPopout
        self.onDoubleClick = onDoubleClick
    }

    private var filteredEvents: [SQLServerXEEventData] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return viewModel.eventData }
        return viewModel.eventData.filter { event in
            event.eventName.lowercased().contains(trimmed)
            || event.fields.values.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.selectedSessionName != nil && !viewModel.eventData.isEmpty {
                searchBar
            }
            if viewModel.selectedSessionName == nil {
                noSessionPlaceholder
            } else if viewModel.eventDataLoadingState == .loading && viewModel.eventData.isEmpty {
                loadingPlaceholder
            } else if case .error(let message) = viewModel.eventDataLoadingState {
                errorPlaceholder(message)
            } else {
                eventTable
                    .overlay {
                        if viewModel.eventData.isEmpty {
                            emptyPlaceholder
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Background.primary)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ColorTokens.Text.tertiary)
            TextField("Filter events", text: $searchText, prompt: Text("Search by event name or field value"))
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                .buttonStyle(.plain)
            }

            Text("\(filteredEvents.count) of \(viewModel.eventData.count)")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary)
    }

    // MARK: - Event Table

    private var eventTable: some View {
        Table(filteredEvents.sorted(using: eventSortOrder), selection: $selection, sortOrder: $eventSortOrder) {
            TableColumn("Timestamp", value: \.sortableTimestamp) { event in
                Text(formattedTimestamp(event.timestamp))
                    .font(TypographyTokens.Table.date)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(180)

            TableColumn("Event", value: \.eventName) { event in
                Text(event.eventName)
                    .font(TypographyTokens.Table.name)
                    .foregroundStyle(ColorTokens.Text.primary)
            }
            .width(200)
            
            TableColumn("Details") { event in
                let sqlText = event.fields["sql_text"] ?? event.fields["statement"] ?? event.fields["batch_text"]
                if let sql = sqlText, let onPopout = onPopout {
                    SQLQueryCell(sql: sql, onPopout: onPopout)
                } else {
                    Text(summaryFields(event.fields))
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: SQLServerXEEventData.ID.self) { ids in
            Button {
                Task {
                    let handle = AppDirector.shared.activityEngine.begin("Refreshing event data", connectionSessionID: viewModel.connectionSessionID)
                    await viewModel.loadEventData()
                    handle.succeed()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            
            if let id = ids.first, let event = viewModel.eventData.first(where: { $0.id == id }) {
                Button {
                    pushEventInspector(event, toggle: true)
                } label: {
                    Label("View Details", systemImage: "info.circle")
                }
                
                if let sql = event.fields["sql_text"] ?? event.fields["statement"] ?? event.fields["batch_text"], let onPopout = onPopout {
                    Button {
                        onPopout(sql)
                    } label: {
                        Label("Query Details", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                viewModel.eventData = []
            } label: {
                Label("Clear List", systemImage: "xmark.circle")
            }
        } primaryAction: { _ in
            if let onDoubleClick = onDoubleClick {
                onDoubleClick()
            } else if let id = selection.first, let event = viewModel.eventData.first(where: { $0.id == id }) {
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
        let sqlText = event.fields["sql_text"] ?? event.fields["statement"] ?? event.fields["batch_text"]
        let fields: [DatabaseObjectInspectorContent.Field] = event.fields
            .filter { $0.key != "sql_text" && $0.key != "statement" && $0.key != "batch_text" }
            .sorted(by: { $0.key < $1.key })
            .map { .init(label: $0.key, value: $0.value) }

        let content = DatabaseObjectInspectorContent(
            title: event.eventName,
            subtitle: formattedTimestamp(event.timestamp),
            sqlText: sqlText,
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
        TabInitializingPlaceholder(
            icon: "bolt.horizontal",
            title: "Loading Event Data",
            subtitle: "Reading event data stream..."
        )
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

import SwiftUI
import SQLServerKit

struct ExtendedEventsDataView: View {
    @Bindable var viewModel: ExtendedEventsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sessionSelector
            Divider()

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
    }

    // MARK: - Session Selector

    private var sessionSelector: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("Session:")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)

            Picker("Session", selection: sessionBinding) {
                Text("Select a session").tag(Optional<String>.none)
                ForEach(runningSessions, id: \.name) { session in
                    Text(session.name).tag(Optional(session.name))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 250)

            Button {
                Task { await viewModel.loadEventData() }
            } label: {
                Label("Load Events", systemImage: "arrow.clockwise")
                    .font(TypographyTokens.detail)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedSessionName == nil)

            Spacer()

            if !viewModel.eventData.isEmpty {
                Text("\(viewModel.eventData.count) events")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }

    private var sessionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedSessionName },
            set: { newValue in
                if let name = newValue {
                    Task {
                        await viewModel.selectSession(name)
                        await viewModel.loadEventData()
                    }
                } else {
                    viewModel.selectedSessionName = nil
                    viewModel.eventData = []
                }
            }
        )
    }

    private var runningSessions: [SQLServerXESession] {
        viewModel.sessions.filter(\.isRunning)
    }

    // MARK: - Event Table

    private var eventTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            eventTableHeader
            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.eventData) { event in
                        eventRow(event)
                        Divider()
                    }
                }
            }
        }
    }

    private var eventTableHeader: some View {
        HStack(spacing: 0) {
            Text("Timestamp")
                .frame(width: 180, alignment: .leading)
            Text("Event")
                .frame(width: 200, alignment: .leading)
            Text("Details")
                .frame(minWidth: 200, alignment: .leading)
        }
        .font(TypographyTokens.compact.weight(.semibold))
        .foregroundStyle(ColorTokens.Text.secondary)
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xxxs)
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }

    private func eventRow(_ event: SQLServerXEEventData) -> some View {
        HStack(spacing: 0) {
            Text(formattedTimestamp(event.timestamp))
                .font(TypographyTokens.monospaced)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 180, alignment: .leading)

            Text(event.eventName)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .frame(width: 200, alignment: .leading)
                .lineLimit(1)

            Text(summaryFields(event.fields))
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(minWidth: 200, alignment: .leading)
                .lineLimit(2)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xxxs)
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

import SwiftUI
import AppKit
import SQLServerKit
import UniformTypeIdentifiers

struct ExtendedEventsToolbar: View {
    @Bindable var viewModel: ExtendedEventsViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Spacer()
            exportButton
            createButton
            refreshButton
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }

    private var exportButton: some View {
        Button {
            exportEventsToFile()
        } label: {
            Label("Export Events", systemImage: "square.and.arrow.up")
                .font(TypographyTokens.detail)
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.eventData.isEmpty)
    }

    private var createButton: some View {
        Button {
            viewModel.showCreateSheet = true
        } label: {
            Label("New Session", systemImage: "plus")
                .font(TypographyTokens.detail)
        }
        .buttonStyle(.borderless)
    }

    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.loadSessions()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(TypographyTokens.detail)
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.loadingState == .loading)
    }

    private func exportEventsToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.nameFieldStringValue = "xe_events.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let events = viewModel.eventData
        let isCSV = url.pathExtension.lowercased() == "csv"

        do {
            if isCSV {
                var csv = "timestamp,event_name,fields\n"
                for event in events {
                    let ts = event.timestamp.map { ISO8601DateFormatter().string(from: $0) } ?? ""
                    let fields = event.fields.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
                    let escapedFields = fields.replacingOccurrences(of: "\"", with: "\"\"")
                    csv += "\"\(ts)\",\"\(event.eventName)\",\"\(escapedFields)\"\n"
                }
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } else {
                let jsonEvents = events.map { event -> [String: Any] in
                    var dict: [String: Any] = [
                        "event_name": event.eventName,
                        "fields": event.fields
                    ]
                    if let ts = event.timestamp {
                        dict["timestamp"] = ISO8601DateFormatter().string(from: ts)
                    }
                    return dict
                }
                let data = try JSONSerialization.data(withJSONObject: jsonEvents, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: url)
            }
        } catch {
            // Export errors are non-critical — no UI alert needed
        }
    }
}

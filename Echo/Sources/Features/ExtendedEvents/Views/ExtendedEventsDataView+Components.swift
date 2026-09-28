import Foundation
import SwiftUI

extension ExtendedEventsDataView {
    func formattedTimestamp(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    func summaryFields(_ fields: [String: String]) -> String {
        let priority = ["sql_text", "database_name", "duration", "username", "statement"]
        var parts: [String] = []
        for key in priority {
            if let value = fields[key], !value.isEmpty {
                let truncated = value.count > 80 ? String(value.prefix(80)) + "…" : value
                parts.append("\(key): \(truncated)")
            }
        }
        if parts.isEmpty {
            parts = Array(fields.prefix(3).map { "\($0.key): \($0.value)" })
        }
        return parts.joined(separator: " | ")
    }

    var noSessionPlaceholder: some View {
        TabContentUnavailableView("No Session Selected", systemImage: "waveform.path.ecg") {
            Text("Select a running session to view captured events.")
        }
    }

    var loadingPlaceholder: some View {
        TabInitializingPlaceholder(
            icon: "bolt.horizontal",
            title: "Loading Event Data",
            subtitle: "Reading the event data stream…"
        )
    }

    func errorPlaceholder(_ message: String) -> some View {
        TabContentUnavailableView("Could Not Load Event Data", systemImage: "exclamationmark.triangle") {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await viewModel.loadEventData() } }
                .buttonStyle(.bordered)
        }
    }

    var emptyPlaceholder: some View {
        TabContentUnavailableView("No Events Captured", systemImage: "tray") {
            Text("The session's ring buffer is empty. Wait for activity, then refresh.")
        } actions: {
            Button("Refresh") { Task { await viewModel.loadEventData() } }
                .buttonStyle(.bordered)
        }
    }
}

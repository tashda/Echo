import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct QueryResultsSection: View {
    @ObservedObject var tab: QueryTab
    @State private var selectedTab: ResultTab = .results

    enum ResultTab: Hashable {
        case results
        case messages
    }

    var body: some View {
        VStack(spacing: 0) {
            if tab.hasExecutedAtLeastOnce || tab.isExecuting || tab.errorMessage != nil {
                toolbar
                Divider().opacity(0.35)
                content
            } else {
                placeholder
            }
            statusBar
        }
        .background(Color.clear)
        .onChange(of: tab.results?.rows.count) { _, newCount in
            if newCount != nil {
                selectedTab = .results
            }
        }
        .onChange(of: tab.errorMessage) { _, error in
            if error != nil {
                selectedTab = .messages
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Picker("", selection: $selectedTab) {
                Text("Results").tag(ResultTab.results)
                Text("Messages").tag(ResultTab.messages)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            .labelsHidden()

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if tab.isExecuting {
                executingView
            } else if let error = tab.errorMessage {
                errorView(error)
            } else {
                switch selectedTab {
                case .results:
                    resultsView
                case .messages:
                    messagesView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(platformBackground)
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Results Yet")
                .font(.headline)
            Text("Run a query to see data appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var executingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Executing query…")
                .font(.headline)
            Text("Please wait while we fetch your data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text("Query Failed")
                .font(.headline)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var resultsView: some View {
        Group {
            if let results = tab.results, !results.rows.isEmpty {
                HighPerformanceGridView(resultSet: results)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if tab.results != nil {
                VStack(spacing: 12) {
                    Image(systemName: "tablecells.badge.ellipsis")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No Rows Returned")
                        .font(.headline)
                    Text("The query executed successfully but returned no data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
    }

    private var messagesView: some View {
        Group {
            if tab.messages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "message")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No Messages Yet")
                        .font(.headline)
                    Text("Server messages will appear here after your query runs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MessagesTableView(messages: tab.messages)
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
            }
        }
    }

    private var statusBar: some View {
        Group {
            if tab.isExecuting || tab.hasExecutedAtLeastOnce {
                VStack(spacing: 0) {
                    Divider().opacity(0.3)
                    HStack(spacing: 0) {
                        Spacer()

                        HStack(spacing: 8) {
                            rowCountBubble
                            timeIndicatorBubble
                            statusIndicatorBubble
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    private var rowCountBubble: some View {
        HStack(spacing: 6) {
            Image(systemName: "tablecells")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            if tab.isExecuting {
                Text("\(tab.currentRowCount ?? 0)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else if let results = tab.results {
                Text("\(results.rows.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }

    private var timeIndicatorBubble: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: tab.isExecuting)

            Text(formatTimeInterval(tab.isExecuting ? tab.currentExecutionTime : (tab.lastExecutionTime ?? 0)))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }

    private var statusIndicatorBubble: some View {
        HStack(spacing: 6) {
            if tab.isExecuting {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                Text("Running")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            } else if tab.wasCancelled {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.gray)
                Text("Canceled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
            } else if tab.errorMessage != nil {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red)
                Text("Failed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
            } else if tab.hasExecutedAtLeastOnce {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.green)
                Text("Success")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusBackgroundColor.opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(statusBorderColor.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }

    private var statusBackgroundColor: Color {
        if tab.isExecuting {
            return .orange
        } else if tab.wasCancelled {
            return .gray
        } else if tab.errorMessage != nil {
            return .red
        } else {
            return .green
        }
    }

    private var statusBorderColor: Color {
        if tab.isExecuting {
            return .orange
        } else if tab.wasCancelled {
            return .gray
        } else if tab.errorMessage != nil {
            return .red
        } else {
            return .green
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let milliseconds = Int((interval.truncatingRemainder(dividingBy: 1)) * 1000)
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%03d", minutes, seconds, milliseconds)
    }

    private var platformBackground: Color {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(UIColor.systemBackground)
#endif
    }
}

private struct MessagesTableView: View {
    let messages: [QueryExecutionMessage]
    @State private var expanded: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(messages) { message in
                    messageRow(message)
                    if expanded.contains(message.id) {
                        detailRow(message)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func messageRow(_ message: QueryExecutionMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Severity icon
            Image(systemName: message.severity.systemImage)
                .foregroundStyle(message.severity.tint)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 20)

            // Message content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(message.message)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(.primary)

                    Text(message.formattedTimestamp)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                if message.duration != nil {
                    Text("Duration: \(message.formattedDuration)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Expand button
            Button {
                toggle(message)
            } label: {
                Image(systemName: expanded.contains(message.id) ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(message)
        }
    }

    private func detailRow(_ message: QueryExecutionMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Object {")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                jsonField(key: "message", value: "\"\(message.message)\"")
                jsonField(key: "time", value: "\"\(ISO8601DateFormatter().string(from: message.timestamp))\"")
                jsonField(key: "severity", value: "\"\(message.severity.rawValue)\"")

                if let duration = message.duration {
                    jsonField(key: "duration", value: String(format: "%.3f", duration))
                }

                if let procedure = message.procedure {
                    jsonField(key: "procedure", value: "\"\(procedure)\"")
                }

                if let line = message.line {
                    jsonField(key: "line", value: "\(line)")
                }

                if message.delta > 0 {
                    jsonField(key: "delta", value: String(format: "%.3f", message.delta))
                }

                // Additional metadata
                ForEach(message.metadata.keys.sorted(), id: \.self) { key in
                    if let value = message.metadata[key] {
                        jsonField(key: key, value: "\"\(value)\"")
                    }
                }
            }
            .padding(.leading, 16)

            Text("}")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.02))
    }

    private func jsonField(key: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(":")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private func toggle(_ message: QueryExecutionMessage) {
        if expanded.contains(message.id) {
            expanded.remove(message.id)
        } else {
            expanded.insert(message.id)
        }
    }
}

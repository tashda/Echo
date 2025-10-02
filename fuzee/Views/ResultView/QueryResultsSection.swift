import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct QueryResultsSection: View {
    @ObservedObject var query: QueryEditorState
    @State private var selectedTab: ResultTab = .results
    @State private var tableSelection: Set<ResultRow.ID> = []

    enum ResultTab: Hashable {
        case results
        case messages
    }

    var body: some View {
        VStack(spacing: 0) {
            if query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil {
                toolbar
                Divider().opacity(0.35)
                content
            } else {
                placeholder
            }
            statusBar
        }
        .background(Color.clear)
        .onChange(of: query.results?.rows.count) { _, newCount in
            if newCount != nil {
                selectedTab = .results
                tableSelection.removeAll()
            }
        }
        .onChange(of: query.errorMessage) { _, error in
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
            if query.isExecuting {
                executingView
            } else if let error = query.errorMessage {
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
            if tableRows.isEmpty {
                if query.results != nil {
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
            } else {
                VStack(spacing: 0) {
                    resultsSummary
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    Table(tableRows, selection: $tableSelection) {
                        TableColumn("#") { row in
                            Text("\(row.displayIndex)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        ForEach(Array(tableColumns.enumerated()), id: \.element.id) { index, column in
                            TableColumn(column.name) { row in
                                valueText(for: row, columnIndex: index)
                            }
                        }
                    }
                    .tableStyle(.inset(alternatesRowBackgrounds: true))
                    .textSelection(.enabled)
                }
            }
        }
    }

    private var messagesView: some View {
        Group {
            if query.messages.isEmpty {
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(query.messages) { message in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("#\(message.index)")
                                        .font(.system(size: 11, weight: .semibold))

                                    Text(message.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text(message.severity.displayName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(message.severity.tint)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(message.severity.tint.opacity(0.1), in: Capsule())
                                }

                                Text(message.message)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)

                                if !message.metadata.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(message.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                            Text("\(key): \(value)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var statusBar: some View {
        Group {
            if query.isExecuting || query.hasExecutedAtLeastOnce {
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

            if query.isExecuting {
                Text("\(query.currentRowCount ?? 0)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else if query.results != nil {
                Text("\(rowCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            } else {
                Text("—")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private var timeIndicatorBubble: some View {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 1

        return HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            if query.isExecuting {
                Text(formatter.string(from: NSNumber(value: query.currentExecutionTime)) ?? "0.0s")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.orange)
            } else if let duration = query.lastExecutionTime {
                Text(formatter.string(from: NSNumber(value: duration)) ?? "0.0s")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private var statusIndicatorBubble: some View {
        let bubbleColor: Color
        let label: String
        let icon: String

        if query.isExecuting {
            bubbleColor = Color.red.opacity(0.12)
            label = "Executing"
            icon = "bolt.fill"
        } else if query.wasCancelled {
            bubbleColor = Color.yellow.opacity(0.12)
            label = "Cancelled"
            icon = "stop.fill"
        } else if query.errorMessage != nil {
            bubbleColor = Color.orange.opacity(0.12)
            label = "Error"
            icon = "exclamationmark.triangle.fill"
        } else if query.hasExecutedAtLeastOnce {
            bubbleColor = Color.green.opacity(0.12)
            label = "Completed"
            icon = "checkmark.circle.fill"
        } else {
            bubbleColor = Color.accentColor.opacity(0.12)
            label = "Ready"
            icon = "clock"
        }

        return bubble(label: label, image: icon, color: bubbleColor)
    }

    private func bubble(label: String, image: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: image)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color, in: Capsule())
    }

    private var platformBackground: some View {
#if os(macOS)
        Color(nsColor: .textBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }

    private var tableColumns: [ColumnInfo] {
        query.results?.columns ?? []
    }

    private var tableRows: [ResultRow] {
        guard let results = query.results else { return [] }
        return results.rows.enumerated().map { ResultRow(id: $0.offset, values: $0.element) }
    }

    private var rowCount: Int {
        tableRows.count
    }

    private func valueText(for row: ResultRow, columnIndex: Int) -> some View {
        let value = row.value(at: columnIndex)
        if let value {
            return Text(value)
                .foregroundStyle(Color.primary)
                .font(.system(size: 12))
        } else {
            return Text("NULL")
                .foregroundStyle(Color.secondary)
                .font(.system(size: 12))
                .italic()
        }
    }

    private var resultsSummary: some View {
        HStack(spacing: 12) {
            Text("\(rowCount) row\(rowCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let total = query.results?.totalRowCount, total > rowCount {
                Text("Showing first \(rowCount) of \(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct ResultRow: Identifiable, Hashable {
        let id: Int
        let values: [String?]

        var displayIndex: Int { id + 1 }

        func value(at index: Int) -> String? {
            guard index < values.count else { return nil }
            return values[index]
        }
    }
}

import SwiftUI

struct QueryResultsSection: View {
    @ObservedObject var tab: QueryTab
    @State private var selectedTab: ResultTab = .results
    @EnvironmentObject private var themeManager: ThemeManager

    enum ResultTab {
        case results, messages
    }

    var body: some View {
        VStack(spacing: 0) {
            if let results = tab.results {
                // Tab picker
                HStack {
                    Picker("View", selection: $selectedTab) {
                        Text("Results").tag(ResultTab.results)
                        Text("Messages").tag(ResultTab.messages)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeManager.windowBackground)

                Divider()

                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .results:
                        if results.rows.isEmpty {
                            ContentUnavailableView(
                                "No Rows",
                                systemImage: "tablecells",
                                description: Text("The query executed successfully but returned no rows.")
                            )
                        } else {
                            HighPerformanceGridView(resultSet: results)
                        }
                    case .messages:
                        EnhancedMessagesView(results: results)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let errorMessage = tab.errorMessage {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)

                    VStack(spacing: 8) {
                        Text("Query Error")
                            .font(.headline)

                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)

            } else if tab.isExecuting {
                // Loading state with native macOS appearance
                VStack(spacing: 24) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .controlSize(.regular)
                        .scaleEffect(1.2)

                    VStack(spacing: 8) {
                        Text("Executing Query...")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Please wait while your query is being processed")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // No results yet
                ContentUnavailableView {
                    Label("No Results", systemImage: "tablecells")
                } description: {
                    Text("Run a SQL query to see results here")
                } actions: {
                    Button("Run Example Query") {
                        // This could trigger an example query
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Status bar
            statusBar
        }
    }

    @ViewBuilder
    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                // Left side - main status
                if let errorMessage = tab.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .lineLimit(1)
                    }
                } else {
                    Text("Ready")
                }

                Spacer()

                // Right side - detailed execution info
                if tab.isExecuting {
                    HStack(spacing: 16) {
                        // Timer with spinning icon
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, isActive: true)
                            Text(formatExecutionTime(tab.currentExecutionTime))
                                .font(.system(.caption, design: .monospaced))
                        }

                        // Row count with running number
                        HStack(spacing: 4) {
                            Image("table_list")
                                .foregroundStyle(.blue)
                            Text("\(tab.currentRowCount ?? 0)")
                                .font(.system(.caption, design: .monospaced))
                        }

                        // Status with running indicator
                        HStack(spacing: 4) {
                            Image(systemName: "circle.dotted")
                                .foregroundStyle(.green)
                                .symbolEffect(.variableColor.iterative, isActive: true)
                            Text("Running")
                        }
                    }
                } else if let results = tab.results, let duration = tab.lastExecutionTime {
                    HStack(spacing: 16) {
                        // Timer with checkmark
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(formatExecutionTime(duration))
                                .font(.system(.caption, design: .monospaced))
                        }

                        // Row count
                        HStack(spacing: 4) {
                            Image("table_list")
                                .foregroundStyle(.blue)
                            Text("\(results.rows.count)")
                                .font(.system(.caption, design: .monospaced))
                        }

                        // Status finished
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Finished")
                        }
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(themeManager.windowBackground)
    }

    private func formatExecutionTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d:%02d", 0, minutes, seconds)
        }
    }
}

struct MessagesView: View {
    let results: QueryResultSet
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Response")
                        .font(.headline)

                    if let commandTag = results.commandTag, !commandTag.isEmpty {
                        Text(commandTag)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeManager.backgroundColor)
                            )
                    } else {
                        Text("No messages from server.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let totalRowCount = results.totalRowCount {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Statistics")
                            .font(.headline)

                        Text("Total rows: \(totalRowCount)")
                            .font(.callout)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

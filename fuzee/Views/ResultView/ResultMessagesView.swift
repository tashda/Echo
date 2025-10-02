import SwiftUI
#if !os(macOS)
import UIKit
#endif

struct ResultMessagesView: View {
    let results: QueryResultSet
    @State private var queryMessages: [QueryMessage] = []
    @State private var expandedMessages: Set<UUID> = []
    @State private var columnWidths: [CGFloat] = [60, 300, 80, 70, 80, 150, 60]

    struct QueryMessage: Identifiable {
        let id = UUID()
        let number: Int
        let message: String
        let time: Date
        let delta: TimeInterval
        let duration: TimeInterval?
        let procedure: String?
        let line: String?
        let severity: MessageSeverity
        let details: [String: Any]

        enum MessageSeverity: String, CaseIterable {
            case info = "info"
            case warning = "warning"
            case error = "error"
            case debug = "debug"

            var color: Color {
                switch self {
                case .info: return .blue
                case .warning: return .orange
                case .error: return .red
                case .debug: return .secondary
                }
            }

            var icon: String {
                switch self {
                case .info: return "info.circle"
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.circle"
                case .debug: return "ladybug"
                }
            }
        }
    }

    private var textBackgroundColor: Color {
        #if os(macOS)
        return Color(PlatformColor.textBackgroundColor)
        #else
        return Color(PlatformColor.systemBackground)
        #endif
    }

    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(PlatformColor.controlBackgroundColor)
        #else
        return Color(PlatformColor.secondarySystemBackground)
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            messageHeader

            // Messages table
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Table header
                    messagesTableHeader

                    // Message rows
                    ForEach(queryMessages) { message in
                        messageRow(message: message)

                        // Expanded details
                        if expandedMessages.contains(message.id) {
                            messageDetails(message: message)
                        }
                    }
                }
            }
            .background(textBackgroundColor)
        }
        .onAppear {
            generateQueryMessages()
        }
    }

    var messageHeader: some View {
        HStack {
            Text("Query Messages")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(queryMessages.count) messages")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Clear Messages") {
                queryMessages.removeAll()
                expandedMessages.removeAll()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(controlBackgroundColor.opacity(0.5))
    }

    var messagesTableHeader: some View {
        HStack(spacing: 1) {
            headerCell(title: "Number", columnIndex: 0)
            headerCell(title: "Message", columnIndex: 1)
            headerCell(title: "Time", columnIndex: 2)
            headerCell(title: "Delta", columnIndex: 3)
            headerCell(title: "Duration", columnIndex: 4)
            headerCell(title: "Procedure", columnIndex: 5)
            headerCell(title: "Line", columnIndex: 6)
            Spacer()
        }
        .frame(height: 32)
        .background(controlBackgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.separator),
            alignment: .bottom
        )
    }

    func headerCell(title: String, columnIndex: Int) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(.caption, design: .default))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(width: columnWidths[columnIndex] - 6, alignment: .leading)
                .padding(.horizontal, 6)

            // Resize handle
            Rectangle()
                .fill(Color.clear)
                .frame(width: 6)
                .contentShape(Rectangle())
                #if os(macOS)
                .cursor(.resizeLeftRight)
                #endif
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            resizeColumn(columnIndex: columnIndex, delta: value.translation.width)
                        }
                )
        }
        .frame(width: columnWidths[columnIndex])
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(.separator)
                .opacity(0.5),
            alignment: .trailing
        )
    }

    func resizeColumn(columnIndex: Int, delta: CGFloat) {
        guard columnIndex < columnWidths.count else { return }
        let minWidth: CGFloat = 60
        let maxWidth: CGFloat = 500
        let newWidth = max(minWidth, min(maxWidth, columnWidths[columnIndex] + delta))
        columnWidths[columnIndex] = newWidth
    }

    func messageRow(message: QueryMessage) -> some View {
        HStack(spacing: 1) {
            // Number
            Text("\(message.number)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[0], alignment: .leading)
                .padding(.horizontal, 6)

            // Message with severity icon
            HStack(spacing: 6) {
                Image(systemName: message.severity.icon)
                    .font(.caption)
                    .foregroundStyle(message.severity.color)

                Text(message.message)
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
            }
            .frame(width: columnWidths[1], alignment: .leading)
            .padding(.horizontal, 6)

            // Time
            Text(formatTime(message.time))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[2], alignment: .leading)
                .padding(.horizontal, 6)

            // Delta
            Text(formatDuration(message.delta))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[3], alignment: .leading)
                .padding(.horizontal, 6)

            // Duration
            Text(message.duration.map(formatDuration) ?? "n/a")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[4], alignment: .leading)
                .padding(.horizontal, 6)

            // Procedure
            Text(message.procedure ?? "")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[5], alignment: .leading)
                .padding(.horizontal, 6)

            // Line
            Text(message.line ?? "")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[6], alignment: .leading)
                .padding(.horizontal, 6)

            Spacer()

            // Expand button
            Button {
                if expandedMessages.contains(message.id) {
                    expandedMessages.remove(message.id)
                } else {
                    expandedMessages.insert(message.id)
                }
            } label: {
                Image(systemName: expandedMessages.contains(message.id) ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.trailing, 8)
        }
        .frame(height: 24)
        .background(messageRowBackground(message: message))
        .contentShape(Rectangle())
        .onTapGesture {
            if expandedMessages.contains(message.id) {
                expandedMessages.remove(message.id)
            } else {
                expandedMessages.insert(message.id)
            }
        }
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.separator)
                .opacity(0.1),
            alignment: .bottom
        )
    }

    func messageDetails(message: QueryMessage) -> some View {
        HStack(spacing: 1) {
            // Empty columns for Number
            Spacer()
                .frame(width: columnWidths[0])

            // Object details under Message column
            VStack(alignment: .leading, spacing: 4) {
                Text("Object Details")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    detailRow(key: "message", value: message.message)
                    detailRow(key: "time", value: ISO8601DateFormatter().string(from: message.time))
                    detailRow(key: "severity", value: message.severity.rawValue)

                    if let duration = message.duration {
                        detailRow(key: "duration", value: formatDuration(duration))
                    }

                    if let procedure = message.procedure {
                        detailRow(key: "procedure", value: procedure)
                    }

                    if let line = message.line {
                        detailRow(key: "line", value: line)
                    }
                }
            }
            .frame(width: columnWidths[1], alignment: .leading)
            .padding(.horizontal, 6)

            Spacer()
        }
        .padding(.vertical, 8)
        .background(controlBackgroundColor.opacity(0.3))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.separator)
                .opacity(0.1),
            alignment: .bottom
        )
    }

    func detailRow(key: String, value: String) -> some View {
        HStack {
            Text("\(key):")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    func messageRowBackground(message: QueryMessage) -> Color {
        switch message.severity {
        case .error:
            return Color.red.opacity(0.05)
        case .warning:
            return Color.orange.opacity(0.05)
        case .info:
            return Color.blue.opacity(0.02)
        case .debug:
            return Color.clear
        }
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 0.001 {
            return "< 1 ms"
        } else if duration < 1.0 {
            return "\(Int(duration * 1000)) ms"
        } else if duration < 60.0 {
            return String(format: "%.1f s", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }

    func generateQueryMessages() {
        let baseTime = Date()
        var messages: [QueryMessage] = []

        // Query execution started
        messages.append(QueryMessage(
            number: 1,
            message: "Query execution started",
            time: baseTime,
            delta: 0,
            duration: nil,
            procedure: nil,
            line: nil,
            severity: .info,
            details: [
                "message": "Query execution started",
                "time": baseTime,
                "severity": "info"
            ]
        ))

        // Query execution finished
        let finishTime = baseTime.addingTimeInterval(0.505)
        messages.append(QueryMessage(
            number: 2,
            message: "Query execution finished",
            time: finishTime,
            delta: 0.505,
            duration: 0.505,
            procedure: nil,
            line: nil,
            severity: .info,
            details: [
                "message": "Query execution finished",
                "time": finishTime,
                "severity": "info"
            ]
        ))

        // Add command tag if available
        if let commandTag = results.commandTag, !commandTag.isEmpty {
            let responseTime = finishTime.addingTimeInterval(0.002)
            messages.append(QueryMessage(
                number: 3,
                message: commandTag,
                time: responseTime,
                delta: 0.507,
                duration: nil,
                procedure: nil,
                line: nil,
                severity: .info,
                details: [
                    "message": commandTag,
                    "time": responseTime,
                    "severity": "info",
                    "rows_returned": results.rows.count,
                    "columns": results.columns.count
                ]
            ))
        }

        // Query session information
        let sessionTime = finishTime.addingTimeInterval(5.0)
        messages.append(QueryMessage(
            number: messages.count + 1,
            message: "Query session active",
            time: sessionTime,
            delta: 5.505,
            duration: 5.505,
            procedure: nil,
            line: nil,
            severity: .debug,
            details: [
                "message": "Query session active",
                "time": sessionTime,
                "severity": "debug"
            ]
        ))

        self.queryMessages = messages
    }
}

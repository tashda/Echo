import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct ResultMessagesView: View {
    let results: QueryResultSet

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var messages: [Message] = []
    @State private var expandedRows: Set<UUID> = []
    private let columnWidths: [CGFloat] = [64, 320, 110, 90, 110, 160, 80]

    struct Message: Identifiable {
        struct Detail: Identifiable {
            let id = UUID()
            let key: String
            let value: String
            let highlight: Highlight

            enum Highlight {
                case normal
                case emphasis
                case warning

                var valueColor: Color {
                    switch self {
                    case .normal:
                        return Color.primary
                    case .emphasis:
                        return Color.accentColor
                    case .warning:
                        return Color.orange
                    }
                }
            }
        }

        enum Severity: String, CaseIterable {
            case info, warning, error, debug

            var iconName: String {
                switch self {
                case .info: return "info.circle"
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.octagon"
                case .debug: return "ladybug"
                }
            }

            func tint(using theme: ThemeManager) -> Color {
                switch self {
                case .info:
                    return theme.accentColor
                case .warning:
                    return Color.orange
                case .error:
                    return Color.red
                case .debug:
                    return Color.secondary
                }
            }
        }

        let id = UUID()
        let sequence: Int
        let title: String
        let timestamp: Date
        let delta: TimeInterval
        let duration: TimeInterval?
        let procedure: String?
        let line: String?
        let severity: Severity
        let details: [Detail]
    }

    private var headerBackground: Color {
        themeManager.surfaceBackground
    }

    private var gridBackground: Color {
        themeManager.windowBackground
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if messages.isEmpty {
                emptyState
            } else {
                tableView
            }
        }
        .background(gridBackground)
        .onAppear {
            buildMessages()
        }
    }

    // MARK: - Components

    private var headerView: some View {
        HStack(spacing: 16) {
            Label("Messages", systemImage: "text.bubble")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(themeManager.surfaceForeground)

            Spacer()

            HStack(spacing: 12) {
                ForEach(Message.Severity.allCases, id: \.self) { severity in
                    let count = messages.filter { $0.severity == severity }.count
                    Label("\(severity.rawValue.capitalized) (\(count))", systemImage: severity.iconName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(severity.tint(using: themeManager))
                }
            }

            Spacer()

            Button {
                messages.removeAll()
                expandedRows.removeAll()
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(headerBackground)
    }

    private var tableView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                tableHeader
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                    messageRow(message, index: index)
                    if expandedRows.contains(message.id) {
                        messageDetails(message, index: index)
                    }
                    Divider()
                }
            }
        }
        .background(gridBackground)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            headerCell("Number", width: columnWidths[0], alignment: .leading)
            headerCell("Message", width: columnWidths[1], alignment: .leading)
            headerCell("Time", width: columnWidths[2], alignment: .leading)
            headerCell("Delta", width: columnWidths[3], alignment: .leading)
            headerCell("Duration", width: columnWidths[4], alignment: .leading)
            headerCell("Procedure", width: columnWidths[5], alignment: .leading)
            headerCell("Line", width: columnWidths[6], alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(headerBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func headerCell(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: alignment)
    }

    private func messageRow(_ message: Message, index: Int) -> some View {
        let isExpanded = expandedRows.contains(message.id)
        return HStack(spacing: 0) {
            Text("\(message.sequence)")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[0], alignment: .leading)

            HStack(spacing: 8) {
                Image(systemName: message.severity.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(message.severity.tint(using: themeManager))
                Text(message.title)
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.surfaceForeground)
                    .lineLimit(1)
            }
            .frame(width: columnWidths[1], alignment: .leading)

            Text(formattedTime(message.timestamp))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[2], alignment: .leading)

            Text(formattedDuration(message.delta))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[3], alignment: .leading)

            Text(message.duration.map(formattedDuration) ?? "—")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[4], alignment: .leading)

            Text(message.procedure ?? "")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[5], alignment: .leading)

            Text(message.line ?? "")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: columnWidths[6], alignment: .leading)

            Spacer(minLength: 0)

            Button {
                toggle(message.id)
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.trailing, 10)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 28, alignment: .center)
        .background(rowBackground(index: index, severity: message.severity))
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(message.id)
        }
    }

    private func messageDetails(_ message: Message, index: Int) -> some View {
        let indent = columnWidths[0] + 12
        let detailBackground = headerBackground.opacity(0.65)

        return HStack(spacing: 0) {
            Color.clear.frame(width: indent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Object {")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)

                ForEach(message.details) { detail in
                    HStack(alignment: .top, spacing: 6) {
                        Text(detail.key + ":")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)

                        Text(detail.value)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(detail.highlight.valueColor)
                            .textSelection(.enabled)
                    }
                }

                Text("}")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(detailBackground)
            .cornerRadius(6)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .background(rowBackground(index: index, severity: message.severity).opacity(0.4))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Messages")
                .font(.system(size: 16, weight: .semibold))
            Text("Server and execution output will appear here once available.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(gridBackground)
    }

    // MARK: - Helpers

    private func toggle(_ id: UUID) {
        if expandedRows.contains(id) {
            expandedRows.remove(id)
        } else {
            expandedRows.insert(id)
        }
    }

    private func rowBackground(index: Int, severity: Message.Severity) -> some View {
        var base = themeManager.surfaceBackground
        if themeManager.resultsAlternateRowShading && index.isMultiple(of: 2) {
            base = base.opacity(0.92)
        }

        let overlay: Color
        switch severity {
        case .error:
            overlay = Color.red.opacity(0.08)
        case .warning:
            overlay = Color.orange.opacity(0.06)
        case .info:
            overlay = themeManager.accentColor.opacity(0.04)
        case .debug:
            overlay = Color.clear
        }
        return base.overlay(overlay)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formattedDuration(_ value: TimeInterval) -> String {
        if value == 0 {
            return "0"
        } else if value < 1.0 {
            return String(format: "%.0f ms", value * 1000)
        } else if value < 60 {
            return String(format: "%.2f s", value)
        } else {
            let minutes = Int(value / 60)
            let seconds = Int(value.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }

    private func buildMessages() {
        // Placeholder content until live server messages are wired in.
        let baseTime = Date()
        var builder: [Message] = []

        builder.append(
            Message(
                sequence: 1,
                title: "Query execution started",
                timestamp: baseTime,
                delta: 0,
                duration: nil,
                procedure: nil,
                line: nil,
                severity: .info,
                details: [
                    .init(key: "message", value: "Query execution started", highlight: .emphasis),
                    .init(key: "time", value: ISO8601DateFormatter().string(from: baseTime), highlight: .normal),
                    .init(key: "severity", value: "info", highlight: .normal)
                ]
            )
        )

        let finish = baseTime.addingTimeInterval(0.712)
        builder.append(
            Message(
                sequence: 2,
                title: "Query execution finished",
                timestamp: finish,
                delta: finish.timeIntervalSince(baseTime),
                duration: finish.timeIntervalSince(baseTime),
                procedure: nil,
                line: nil,
                severity: .info,
                details: [
                    .init(key: "message", value: "Query execution finished", highlight: .emphasis),
                    .init(key: "time", value: ISO8601DateFormatter().string(from: finish), highlight: .normal),
                    .init(key: "severity", value: "info", highlight: .normal),
                    .init(key: "rows", value: "\(results.rows.count)", highlight: .normal),
                    .init(key: "columns", value: "\(results.columns.count)", highlight: .normal)
                ]
            )
        )

        if let tag = results.commandTag, !tag.isEmpty {
            let tagTime = finish.addingTimeInterval(0.031)
            builder.append(
                Message(
                    sequence: 3,
                    title: tag,
                    timestamp: tagTime,
                    delta: tagTime.timeIntervalSince(baseTime),
                    duration: nil,
                    procedure: nil,
                    line: nil,
                    severity: .info,
                    details: [
                        .init(key: "commandTag", value: tag, highlight: .emphasis),
                        .init(key: "time", value: ISO8601DateFormatter().string(from: tagTime), highlight: .normal)
                    ]
                )
            )
        }

        messages = builder
    }
}

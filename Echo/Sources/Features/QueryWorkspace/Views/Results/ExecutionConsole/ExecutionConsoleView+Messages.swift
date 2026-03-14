import SwiftUI

extension ExecutionConsoleView {
    func messageRow(_ message: Message, index: Int) -> some View {
        let isExpanded = expandedRows.contains(message.id)
        return HStack(spacing: 0) {
            Text("\(message.sequence)")
                .font(TypographyTokens.callout.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: columnWidths[0], alignment: .leading)

            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: message.severity.iconName)
                    .font(TypographyTokens.caption2.weight(.medium))
                    .foregroundStyle(message.severity.tint(using: appearanceStore.accentColor))
                Text(message.title)
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
            }
            .frame(width: columnWidths[1], alignment: .leading)

            Text(formattedTime(message.timestamp))
                .font(TypographyTokens.footnote.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: columnWidths[2], alignment: .leading)

            Text(EchoFormatters.duration(message.delta))
                .font(TypographyTokens.footnote.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: columnWidths[3], alignment: .leading)

            Text(message.duration.map(EchoFormatters.duration) ?? "\u{2014}")
                .font(TypographyTokens.footnote.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: columnWidths[4], alignment: .leading)

            Text(message.procedure ?? "")
                .font(TypographyTokens.footnote.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: columnWidths[5], alignment: .leading)

            Text(message.line ?? "")
                .font(TypographyTokens.footnote.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: columnWidths[6], alignment: .leading)

            Spacer(minLength: 0)

            Button {
                toggle(message.id)
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.trailing, SpacingTokens.xs2)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .frame(minHeight: 28, alignment: .center)
        .background(rowBackground(index: index, severity: message.severity))
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(message.id)
        }
    }

    func messageDetails(_ message: Message, index: Int) -> some View {
        let indent = columnWidths[0] + 12
        let detailBackground = headerBackground.opacity(0.65)

        return HStack(spacing: 0) {
            Color.clear.frame(width: indent)

            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text("Object {")
                    .font(TypographyTokens.footnote.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)

                ForEach(message.details) { detail in
                    HStack(alignment: .top, spacing: SpacingTokens.xxs2) {
                        Text(detail.key + ":")
                            .font(TypographyTokens.footnote.monospaced())
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .frame(width: 90, alignment: .leading)

                        Text(detail.value)
                            .font(TypographyTokens.footnote.monospaced())
                            .foregroundStyle(detail.highlight.valueColor)
                            .textSelection(.enabled)
                    }
                }

                Text("}")
                    .font(TypographyTokens.footnote.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .padding(.vertical, SpacingTokens.xs)
            .padding(.horizontal, SpacingTokens.sm)
            .background(detailBackground)
            .cornerRadius(6)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxs2)
        .background(rowBackground(index: index, severity: message.severity).opacity(0.4))
    }

    func buildMessages() {
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

import SwiftUI

/// A statement's messages under its heading (round 41.4, ML1): "Line 7  select * from ba_tbl" and
/// the time, then each message. Messages from no statement (a connection, a maintenance task)
/// have no heading.
struct ConsoleMessageGroupView: View {
    let group: QueryMessageGroup
    var onGoToLine: ((QueryExecutionMessage) -> Void)?
    var onGoToEditorLine: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if let statement = group.statement {
                HStack(spacing: SpacingTokens.xs) {
                    Button("Line \(statement.line)") { onGoToEditorLine?(statement.line) }
                        .buttonStyle(.plain)
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .disabled(onGoToEditorLine == nil)
                        .help("Select line \(statement.line) in the editor")
                    Text(statement.text)
                        .font(TypographyTokens.detail.monospaced())
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: SpacingTokens.xs)
                    if let first = group.messages.first {
                        Text(first.formattedTimestamp)
                            .font(TypographyTokens.detail.monospacedDigit())
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            ForEach(group.messages) { message in
                ConsoleMessageRow(message: message, onGoToLine: onGoToLine)
                    .padding(.leading, group.statement == nil ? SpacingTokens.none : SpacingTokens.sm)
            }
        }
    }
}

/// One message (round 41.4, EE1): its symbol and the text; an error's symbol is red and its text
/// semibold, with SSMS's numbers under it and the line as a link (EM1, LL1). The time is on hover.
struct ConsoleMessageRow: View {
    let message: QueryExecutionMessage
    /// Round 22 LL1 / round 21 J1: puts the editor on the message's line.
    var onGoToLine: ((QueryExecutionMessage) -> Void)?

    private var isError: Bool { message.severity == .error }

    @State private var showsServerMessage = false

    /// The severity's symbol; for a message from the server it opens what the server returned.
    @ViewBuilder
    private var symbol: some View {
        let image = Image(systemName: isError ? "xmark.octagon.fill" : message.severity.systemImage)
            .font(TypographyTokens.detail)
            .foregroundStyle(message.severity.tint)
        if message.isFromServer {
            Button { showsServerMessage.toggle() } label: { image.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .help("Show what the server returned")
                .accessibilityLabel("Show what the server returned")
                .popover(isPresented: $showsServerMessage, arrowEdge: .bottom) { ServerMessagePopover(message: message) }
        } else {
            image
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
            symbol
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(message.message)
                    .font(TypographyTokens.standard.weight(isError ? .semibold : .regular))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let header = message.ssmsHeader {
                    HStack(spacing: SpacingTokens.none) {
                        Text(message.line == nil ? header : header + ", ")
                        if let line = message.line {
                            Button("Line \(line)") { onGoToLine?(message) }
                                .buttonStyle(.link)
                                .disabled(onGoToLine == nil)
                                .help("Select line \(line) in the editor")
                        }
                    }
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(.vertical, SpacingTokens.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .help(message.formattedTimestamp)
        .onTapGesture {
            // J1: clicking the error goes there.
            if isError, message.line != nil { onGoToLine?(message) }
        }
    }
}

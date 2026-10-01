import SwiftUI
import AppKit

/// Messages (round 41.4): no strip at the top, only the counts ("1 error · 2 messages"), which
/// filter when clicked, and a ⋯ menu to copy or clear (MT1); messages grouped under the statement
/// that said them (ML1); errors as a red symbol and a semibold message, no fill (EE1).
struct ExecutionConsoleView: View {
    let executionMessages: [QueryExecutionMessage]
    var onClear: (() -> Void)?
    /// Round 22 LL1 / round 21 J1: a message's line link, or a click on an error.
    var onGoToLine: ((QueryExecutionMessage) -> Void)?
    /// A statement heading's line (ML1).
    var onGoToEditorLine: ((Int) -> Void)?

    @State private var filter: MessageFilter = .all
    @State private var isAutoScrolling = true
    /// The card's floating footer, so the last message scrolls clear of it.
    @Environment(\.cardFooterOverlayHeight) private var footerOverlayHeight

    private var filteredMessages: [QueryExecutionMessage] {
        executionMessages.filter(filter.includes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if executionMessages.isEmpty {
                emptyState
            } else {
                MessageCountsBar(messages: executionMessages, filter: $filter, onCopyAll: copyAll, onClear: onClear)
                messageList
            }
        }
        .background(ColorTokens.Background.primary)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    ForEach(QueryMessageGroup.groups(from: filteredMessages)) { group in
                        ConsoleMessageGroupView(group: group, onGoToLine: onGoToLine, onGoToEditorLine: onGoToEditorLine)
                    }
                    Color.clear.frame(height: SpacingTokens.none).id(Self.bottomID)
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.xs)
            }
            .footerScrollRoom(footerOverlayHeight)
            .onChange(of: executionMessages.count) {
                if isAutoScrolling {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(Self.bottomID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private static let bottomID = "messages-bottom"

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "text.bubble")
                .font(TypographyTokens.iconMedium)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("No Messages")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("What the server says appears here.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func copyAll() {
        let text = QueryMessageGroup.groups(from: filteredMessages).map { group in
            var lines = group.statement.map { ["-- Line \($0.line): \($0.text)"] } ?? []
            lines += group.messages.map { message in
                [message.ssmsHeader, message.message].compactMap { $0 }.joined(separator: "\n")
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Message Filter

enum MessageFilter: String, CaseIterable {
    case all
    case errors
    case warnings
    case others

    func includes(_ message: QueryExecutionMessage) -> Bool {
        switch self {
        case .all: true
        case .errors: message.severity == .error
        case .warnings: message.severity == .warning
        case .others: message.severity != .error && message.severity != .warning
        }
    }
}

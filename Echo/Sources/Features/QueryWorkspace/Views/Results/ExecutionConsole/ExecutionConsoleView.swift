import SwiftUI
import AppKit

struct ExecutionConsoleView: View {
    let executionMessages: [QueryExecutionMessage]
    var onClear: (() -> Void)?

    @State private var filter: MessageFilter = .all
    @State private var isAutoScrolling = true

    private var filteredMessages: [QueryExecutionMessage] {
        switch filter {
        case .all: executionMessages
        case .errors: executionMessages.filter { $0.severity == .error }
        case .warnings: executionMessages.filter { $0.severity == .warning || $0.severity == .error }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            consoleToolbar
            Divider()
            if filteredMessages.isEmpty {
                emptyState
            } else {
                messageList
            }
        }
        .background(ColorTokens.Background.primary)
    }

    // MARK: - Toolbar

    private var consoleToolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("Messages")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            CountBadge(count: filteredMessages.count)

            Spacer()

            filterPicker

            if let onClear {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "trash")
                        .font(TypographyTokens.detail)
                }
                .buttonStyle(.borderless)
                .disabled(executionMessages.isEmpty)
                .help("Clear Messages")
                .accessibilityLabel("Clear Messages")
            }

            Button {
                copyAll()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(TypographyTokens.detail)
            }
            .buttonStyle(.borderless)
            .disabled(filteredMessages.isEmpty)
            .help("Copy All Messages")
            .accessibilityLabel("Copy All Messages")
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs2)
        .background(ColorTokens.Background.secondary)
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(MessageFilter.allCases, id: \.self) { filter in
                Text(filter.label).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 180)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredMessages) { message in
                        ConsoleMessageRow(message: message)
                            .id(message.id)
                        Divider()
                            .padding(.leading, SpacingTokens.md)
                    }
                }
            }
            .onChange(of: executionMessages.count) {
                if isAutoScrolling, let last = filteredMessages.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "text.bubble")
                .font(TypographyTokens.iconMedium)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("No Messages")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("Execution output will appear here.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func copyAll() {
        let text = filteredMessages.map { msg in
            let time = msg.formattedTimestamp
            let severity = msg.severity.displayName.uppercased()
            return "[\(time)] [\(severity)] \(msg.message)"
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Message Filter

enum MessageFilter: String, CaseIterable {
    case all
    case errors
    case warnings

    var label: String {
        switch self {
        case .all: "All"
        case .errors: "Errors"
        case .warnings: "Warnings"
        }
    }
}

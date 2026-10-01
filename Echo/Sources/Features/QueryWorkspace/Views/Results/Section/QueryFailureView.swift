import EchoSense
import SwiftUI

/// A failed query in the results card (round 41.3): a banner at the top with the message, the line
/// it points at, SQL Server's numbers as quiet chips (ED0), and Show in Editor, Messages and Copy
/// Error (EA1).
struct QueryFailureView: View {
    let message: String
    let query: QueryEditorState
    let panelState: BottomPanelState

    @State private var didCopy = false

    private var line: Int? { query.failureLine(for: message) }
    private var chips: [String] { QueryExecutionMessage.errorChips(in: query.messages) }

    var body: some View {
        ResultsStateBanner(
            mark: .symbol("exclamationmark.octagon.fill", tint: ColorTokens.Status.error),
            title: line.map { "Failed on line \($0)" } ?? "Failed",
            detail: message
        ) {
            if !chips.isEmpty {
                HStack(spacing: SpacingTokens.xxs) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(TypographyTokens.detail.monospacedDigit())
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .padding(.horizontal, SpacingTokens.xxs2)
                            .padding(.vertical, SpacingTokens.micro)
                            .background(ColorTokens.Sidebar.hoverFill, in: Capsule())
                    }
                }
            }
            HStack(spacing: SpacingTokens.xs) {
                if line != nil {
                    Button("Show in Editor") { query.showFailureInEditor(message: message) }
                        .keyboardShortcut(.defaultAction)
                }
                Button("Messages") {
                    panelState.selectedSegment = .messages
                }
                Button(didCopy ? "Copied" : "Copy Error") {
                    PlainTextPasteboard.copy(copyText)
                    didCopy = true
                }
            }
            .controlSize(.small)
            .padding(.top, SpacingTokens.xxs)
        }
        .onChange(of: message) { _, _ in didCopy = false }
    }

    /// The numbers as SQL Server prints them over the message: "Msg 248, Level 16, State 1".
    private var copyText: String {
        chips.isEmpty ? message : "\(chips.joined(separator: ", "))\n\(message)"
    }
}

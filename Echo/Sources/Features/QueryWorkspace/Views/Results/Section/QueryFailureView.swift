import SwiftUI

/// A failed query in the results card (plan N4): the message, the line it points at, "Show in
/// Editor" to put the caret there, and the Messages pane one click away.
struct QueryFailureView: View {
    let message: String
    let query: QueryEditorState
    let panelState: BottomPanelState

    /// The editor line: the marked error's, or the reported line mapped from what was sent.
    private var line: Int? {
        if let mark = query.errorMark { return mark.line }
        guard let reported = QueryErrorLocation.line(in: message) else { return nil }
        return query.messageLineMapper?(reported) ?? reported
    }

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Status.error)
            Text(line.map { "Query Failed on Line \($0)" } ?? "Query Failed")
                .font(TypographyTokens.headline)
            Text(message)
                .font(TypographyTokens.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ColorTokens.Text.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: LayoutTokens.FloatingSurface.largeWidth * 1.5)
            HStack(spacing: SpacingTokens.xs) {
                if let line {
                    Button("Show in Editor") {
                        if let mark = query.errorMark {
                            query.editorLineRequest = EditorLineRequest(line: mark.line, range: mark.range)
                        } else {
                            query.editorLineRequest = EditorLineRequest(line: line)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                Button("Show Messages") {
                    panelState.selectedSegment = .messages
                }
            }
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SpacingTokens.xl2)
    }
}

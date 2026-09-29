import SwiftUI

/// A failed query in the results card (plan N4): the message, the line it points at, "Show in
/// Editor" to put the caret there, and the Messages pane one click away.
struct QueryFailureView: View {
    let message: String
    let query: QueryEditorState
    let panelState: BottomPanelState

    private var line: Int? { QueryErrorLocation.line(in: message) }

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
                        query.editorLineRequest = EditorLineRequest(line: line)
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

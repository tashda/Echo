import SwiftUI

/// What an error's bubble says: a title naming the kind of mistake, the message, a detail and,
/// when the server's hint names the right word, a Fix.
nonisolated struct ErrorBubbleContent: Equatable, Sendable {
    let title: String
    let message: String
    var detail: String?
    var fix: QueryErrorMark.Fix?
}

/// Round 28.6 (BB3): the bubble's content. It sits in an NSPopover, which macOS 26 draws as Liquid
/// Glass with a pointer at the word.
struct ErrorBubble: View {
    let content: ErrorBubbleContent
    let onFix: (QueryErrorMark.Fix) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Label(content.title, systemImage: "exclamationmark.octagon.fill")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Status.error)
            Text(content.message)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
            if content.detail != nil || content.fix != nil {
                HStack(spacing: SpacingTokens.sm) {
                    if let detail = content.detail {
                        Text(detail)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let fix = content.fix {
                        Button(fix.title) { onFix(fix) }
                            .controlSize(.small)
                    }
                }
            }
        }
        .textSelection(.enabled)
        .padding(SpacingTokens.sm)
        .frame(maxWidth: LayoutTokens.EditorGutter.errorBubbleMaxWidth, alignment: .leading)
    }
}

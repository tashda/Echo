import EchoSense
import SwiftUI

/// Round 28.7 (R10): the run note on a glass pill: the result's symbol in its colour and the
/// numbers in grey (an error keeps its red words). The detail is in the tooltip.
struct RunNotePill: View {
    let note: QueryRunNote

    private var tint: Color {
        note.isError ? ColorTokens.Status.error : note.isWarning ? ColorTokens.Status.warning : ColorTokens.Status.success
    }

    private var symbol: String {
        note.isError ? "exclamationmark.circle.fill" : note.isWarning ? "stop.circle.fill" : "checkmark.circle.fill"
    }

    /// The note without its leading ✓ or ! (a cancel has none).
    private var words: String {
        note.text.hasPrefix("✓ ") || note.text.hasPrefix("! ") ? String(note.text.dropFirst(2)) : note.text
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(words).foregroundStyle(note.isError ? tint : ColorTokens.Text.secondary)
        }
        .font(TypographyTokens.detail)
        .lineLimit(1)
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxxs)
        .glassEffect(.regular, in: .capsule)
        .help(note.detail)
        .fixedSize()
    }
}

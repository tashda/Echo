import SwiftUI
import EchoSense

/// ES4: the selected suggestion described straight away (no timer), in an inset rounded panel
/// concentric with the popup: what will be inserted, its type, where it comes from and what the
/// schema knows about it, then the keys.
struct AutoCompletionDetailFooter: View {
    let suggestion: SQLAutoCompletionSuggestion
    let nameFont: Font
    let cornerRadius: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutTokens.EchoSense.footerLineSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs2) {
                Text(suggestion.title)
                    .font(nameFont.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                Text(suggestion.kind == .column ? (suggestion.dataType ?? suggestion.displayKindTitle) : suggestion.displayKindTitle)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            if let detail = suggestion.footerDetail {
                Text(detail)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: LayoutTokens.EchoSense.keyHintSpacing) {
                Text("↩ Insert")
                Text("⇥ Complete")
                Text("↑↓ Choose")
                Text("⎋ Close")
            }
            .font(TypographyTokens.label)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .padding(.top, SpacingTokens.xxxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LayoutTokens.EchoSense.footerPadding)
        .background(ColorTokens.EchoSense.footer, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

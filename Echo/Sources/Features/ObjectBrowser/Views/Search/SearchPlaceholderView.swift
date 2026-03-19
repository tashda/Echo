import SwiftUI

struct SearchPlaceholderView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: SpacingTokens.xs2) {
            Image(systemName: systemImage)
                .font(TypographyTokens.title.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text(title)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.md)
            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

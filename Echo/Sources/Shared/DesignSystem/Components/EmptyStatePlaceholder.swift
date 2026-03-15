import SwiftUI

struct EmptyStatePlaceholder: View {
    let icon: String
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: icon)
                .font(TypographyTokens.hero.weight(.light))
                .foregroundStyle(ColorTokens.Text.tertiary)

            VStack(spacing: SpacingTokens.xxs) {
                Text(title)
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)

                if let subtitle {
                    Text(subtitle)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

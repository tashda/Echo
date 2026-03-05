import SwiftUI

struct SearchPlaceholderView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(TypographyTokens.detail)
                .foregroundStyle(.tertiary)
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

import SwiftUI

/// Shared loading placeholder used by activity monitor sections that need baseline data collection.
struct ActivitySectionLoadingView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(subtitle)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

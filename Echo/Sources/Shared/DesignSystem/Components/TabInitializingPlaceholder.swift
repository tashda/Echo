import SwiftUI

/// Shared loading placeholder shown while a tab is fetching its initial data.
/// Use this for any tab type (Activity Monitor, Maintenance, Query Store, etc.)
/// to provide a consistent "initializing" experience.
struct TabInitializingPlaceholder: View {
    let icon: String
    let title: String
    var subtitle: String = "Loading data\u{2026}"

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: SpacingTokens.xxs) {
                Text(title)
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)

                Text(subtitle)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

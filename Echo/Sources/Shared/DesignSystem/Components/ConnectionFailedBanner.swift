import SwiftUI

/// A non-modal inline banner shown when a query tab's dedicated connection
/// failed to establish. Displays the error and offers a retry action.
struct ConnectionFailedBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "bolt.horizontal.circle")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Status.error)
            Text(message)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(2)
            Spacer()
            Button("Retry Connection", action: onRetry)
                .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Status.error.opacity(0.08))
    }
}

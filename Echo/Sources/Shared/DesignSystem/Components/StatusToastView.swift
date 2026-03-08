import SwiftUI

/// A transient toast notification displayed at the top of the content area.
///
/// Used for brief status events like connection changes, index updates, etc.
/// Appears, stays for a few seconds, then fades out automatically.
struct StatusToastView: View {
    let icon: String
    let message: String
    let style: StatusToastStyle

    enum StatusToastStyle {
        case success
        case info
        case warning
        case error

        var iconColor: Color {
            switch self {
            case .success: .green
            case .info: .secondary
            case .warning: .orange
            case .error: .red
            }
        }
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(style.iconColor)
            Text(message)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

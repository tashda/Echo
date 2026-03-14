import SwiftUI

extension TabPreviewCard {
    var previewBackground: LinearGradient {
        LinearGradient(
            colors: [
                appearanceStore.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.18),
                ColorTokens.Text.primary.opacity(colorScheme == .dark ? 0.12 : 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.12 : 0.65),
                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    var cardBorder: some View {
        RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous)
            .stroke(borderColor, lineWidth: isDropTarget ? 2.8 : (isFocused ? 1.4 : 0.9))
    }

    var borderColor: Color {
        if isDropTarget {
            return appearanceStore.accentColor
        }
        if isFocused {
            return appearanceStore.accentColor.opacity(colorScheme == .dark ? 0.55 : 0.4)
        }
        return ColorTokens.Text.primary.opacity(colorScheme == .dark ? 0.16 : 0.08)
    }

    var focusRing: some View {
        RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous)
            .stroke(appearanceStore.accentColor.opacity(isFocused ? 0.38 : 0), lineWidth: 2.8)
    }

    var cardShadow: Color {
        Color.black.opacity(colorScheme == .dark ? (isFocused ? 0.42 : 0.32) : (isFocused ? 0.16 : 0.08))
    }
}

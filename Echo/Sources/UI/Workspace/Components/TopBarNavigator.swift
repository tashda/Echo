import SwiftUI

/// A toolbar-centered capsule similar to Xcode's, sized to the available space.
/// Width = 3/5 of available area between navigation and trailing items, clamped to [350, 800].
/// Height matches `WorkspaceChromeMetrics.toolbarTabBarHeight` to align with circular toolbar icons.
struct TopBarNavigator: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    private let minWidth: CGFloat = 350
    private let idealWidth: CGFloat = 450
    private let maxWidth: CGFloat = 800

    var body: some View {
        GeometryReader { proxy in
            let available = max(proxy.size.width, 0)
            // Use the actual container height so we match toolbar control height exactly.
            let controlHeight = max(WorkspaceChromeMetrics.chromeBackgroundHeight, proxy.size.height)
            // Target 3/5 of available space, clamped to provided bounds.
            let target = clamp(available * 0.6, minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth)

            ZStack {
                // Capsule chrome styled to match Xcode.
                let corner = controlHeight / 2
                let base = RoundedRectangle(cornerRadius: corner, style: .continuous)

                base
                    .fill(capsuleFill)
                    .overlay(
                        base.stroke(capsuleBorder, lineWidth: 1)
                    )
                    .overlay(capsuleTopHighlight(cornerRadius: corner))
                    .shadow(color: capsuleShadowColor, radius: capsuleShadowRadius, y: capsuleShadowYOffset)
                    .frame(width: target, height: controlHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityHidden(true)
    }

    private var capsuleFill: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    Color.white.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var capsuleBorder: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.16)
        }
        return Color.black.opacity(0.09)
    }

    private func capsuleTopHighlight(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                (colorScheme == .dark ? Color.white.opacity(0.28) : Color.white.opacity(0.60)),
                lineWidth: 0.7
            )
            .blendMode(.screen)
            .opacity(0.85)
            .offset(y: -0.5)
    }

    private var capsuleShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.10)
    }
    private var capsuleShadowRadius: CGFloat { colorScheme == .dark ? 6.5 : 4.5 }
    private var capsuleShadowYOffset: CGFloat { colorScheme == .dark ? 2.0 : 1.0 }

    private func clamp(_ value: CGFloat, minWidth: CGFloat, idealWidth: CGFloat, maxWidth: CGFloat) -> CGFloat {
        // Prefer `idealWidth` when there is generous room, otherwise follow value.
        // This yields a pleasant progression while respecting the 3/5 target.
        let clamped = max(minWidth, min(maxWidth, value))
        // Nudge toward ideal when possible.
        if clamped >= idealWidth && clamped <= maxWidth {
            // If value overshoots ideal slightly, bias back to ideal.
            return max(idealWidth, clamped)
        }
        return clamped
    }
}

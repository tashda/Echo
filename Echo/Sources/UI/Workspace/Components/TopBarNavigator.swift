import SwiftUI

/// A toolbar-centered capsule similar to Xcode's, sized to the available space.
/// Width = 3/5 of available area between navigation and trailing items, clamped to [350, 800].
/// Height matches `WorkspaceChromeMetrics.toolbarTabBarHeight` to align with circular toolbar icons.
struct TopBarNavigator: View {
    private let minWidth: CGFloat = 350
    private let idealWidth: CGFloat = 450
    private let maxWidth: CGFloat = 800
    private let height: CGFloat = WorkspaceChromeMetrics.toolbarTabBarHeight

    var body: some View {
        GeometryReader { proxy in
            let available = max(proxy.size.width, 0)
            // Target 3/5 of available space, clamped to provided bounds.
            let target = clamp(available * 0.6, minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth)

            ZStack {
                // Capsule chrome only (content will be added later).
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(toolbarBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .stroke(toolbarBorder, lineWidth: 1)
                    )
                    .frame(width: target, height: height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private var toolbarBackground: some ShapeStyle {
        if #available(macOS 13.0, *) {
            return AnyShapeStyle(.bar)
        } else {
            return AnyShapeStyle(Color.primary.opacity(0.06))
        }
    }

    private var toolbarBorder: Color {
        Color.primary.opacity(0.12)
    }

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


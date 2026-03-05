import SwiftUI

/// Individual breadcrumb segment with Xcode styling
struct BreadcrumbSegmentView: View {
    let segment: BreadcrumbSegment
    let isLast: Bool
    let onTap: () -> Void
    let onMenuTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false

    private var isEnabled: Bool { segment.isEnabled }

    private var textColor: Color {
        if !isEnabled {
            return Color(nsColor: .tertiaryLabelColor)
        }
        return .primary
    }

    private var backgroundColor: Color {
        guard isEnabled, isHovered || isPressed else { return Color.clear }
        if isPressed {
            return colorScheme == .dark
                ? Color.white.opacity(0.14)
                : Color.black.opacity(0.07)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.09)
            : Color.black.opacity(0.045)
    }

    private var borderColor: Color {
        guard isEnabled, isHovered || isPressed else { return Color.clear }
        if isPressed {
            return colorScheme == .dark
                ? Color.white.opacity(0.22)
                : Color.black.opacity(0.12)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.08)
    }

    private var separatorColor: Color {
        Color(nsColor: .tertiaryLabelColor)
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: SpacingTokens.xxxs) {
                if let icon = segment.icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(textColor)
                }

                Text(segment.title)
                    .font(TypographyTokens.label.weight(.regular))
                    .foregroundStyle(textColor)

                // Always in layout to prevent shifting; visibility toggled
                if segment.hasMenu {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        .opacity(isHovered && isEnabled ? 1 : 0)
                }
            }
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(
                Capsule()
                    .fill(backgroundColor)
                    .overlay(Capsule().stroke(borderColor, lineWidth: 0.5))
            )
            .contentShape(Capsule())
            .onTapGesture {
                guard isEnabled else { return }
                if segment.hasMenu {
                    onMenuTap()
                } else {
                    onTap()
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled else { return }
                        if !isPressed {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = true
                            }
                        }
                    }
                    .onEnded { _ in
                        guard isEnabled else { return }
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = false
                        }
                    }
            )

            // Separator — always in layout; opacity toggled so neighbours don't shift
            if !isLast {
                Text("\u{203A}")
                    .font(.system(size: 15, weight: .medium))
                    .scaleEffect(x: 0.65, y: 1.0)
                    .foregroundStyle(separatorColor)
                    .padding(.leading, 1)
                    .padding(.trailing, SpacingTokens.xxs2)
                    .opacity(isHovered ? 0 : 1)
            }
        }
        .onHover { hovering in
            guard isEnabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onChange(of: segment.isEnabled) { _, enabled in
            if !enabled {
                isHovered = false
                isPressed = false
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

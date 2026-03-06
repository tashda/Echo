import SwiftUI

/// Individual breadcrumb segment matching Xcode's scheme-picker style.
struct BreadcrumbSegmentView: View {
    let segment: BreadcrumbSegment
    let isLast: Bool
    let onTap: () -> Void
    let onMenuTap: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    private var isEnabled: Bool { segment.isEnabled }

    private var textColor: Color {
        if !isEnabled { return Color(nsColor: .tertiaryLabelColor) }
        if isPressed { return .primary.opacity(0.7) }
        return .primary
    }

    var body: some View {
        HStack(spacing: 0) {
            segmentContent
                .contentShape(Capsule())
                .onTapGesture {
                    guard isEnabled else { return }
                    if segment.hasMenu { onMenuTap() } else { onTap() }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard isEnabled else { return }
                            if !isPressed { withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                        }
                        .onEnded { _ in
                            guard isEnabled else { return }
                            withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                        }
                )

            // Separator chevron — hidden when this segment is hovered
            if !isLast {
                Image(systemName: "chevron.compact.right")
                    .font(.system(size: 14, weight: .ultraLight))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .padding(.horizontal, 2)
                    .opacity(isHovered ? 0 : 1)
            }
        }
        .onHover { hovering in
            guard isEnabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onChange(of: segment.isEnabled) { _, enabled in
            if !enabled { isHovered = false; isPressed = false }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }

    @ViewBuilder
    private var segmentContent: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            if let icon = segment.icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(textColor)
            }

            Text(segment.title)
                .font(.system(size: 12))
                .foregroundStyle(textColor)

            // Dropdown chevron — appears on hover
            if segment.hasMenu {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .opacity(isHovered && isEnabled ? 1 : 0)
            }
        }
        .padding(.horizontal, SpacingTokens.xxs)
        .padding(.vertical, SpacingTokens.xxxs)
        .background {
            if isHovered && isEnabled {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
    }
}

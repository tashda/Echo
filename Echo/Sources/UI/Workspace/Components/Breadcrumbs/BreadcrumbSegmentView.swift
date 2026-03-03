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
            #if os(macOS)
            return Color(nsColor: .tertiaryLabelColor)
            #else
            return .secondary
            #endif
        }
        if isHovered {
            return .primary
        }
        return segment.isActive ? .primary : .secondary
    }

    private var backgroundColor: Color {
        guard isEnabled else { return Color.clear }
        if isPressed {
            return colorScheme == .dark
                ? Color.white.opacity(0.20)
                : Color.black.opacity(0.12)
        } else if isHovered {
            return colorScheme == .dark
                ? Color.white.opacity(0.14)
                : Color.black.opacity(0.08)
        }
        return Color.clear
    }

    private var borderColor: Color {
        guard isEnabled else { return Color.clear }
        if isPressed {
            return colorScheme == .dark
                ? Color.white.opacity(0.34)
                : Color.black.opacity(0.22)
        } else if isHovered {
            return colorScheme == .dark
                ? Color.white.opacity(0.24)
                : Color.black.opacity(0.18)
        }
        return Color.clear
    }

    private var separatorColor: Color {
        #if os(macOS)
        return Color(nsColor: .tertiaryLabelColor)
        #else
        return .secondary
        #endif
    }

    private var chevronColor: Color {
        #if os(macOS)
        return Color(nsColor: .secondaryLabelColor)
        #else
        return .secondary
        #endif
    }

    private var menuChevronOpacity: Double {
        guard isEnabled else { return 0.2 }
        return isHovered ? 1.0 : 0.55
    }

    var body: some View {
        HStack(spacing: 0) {
            // Segment content
            HStack(spacing: 5) {
                // Icon
                if let icon = segment.icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(textColor)
                }

                // Text
                Text(segment.title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(textColor)

                if segment.hasMenu {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(chevronColor)
                        .opacity(menuChevronOpacity)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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

            // Separator arrow (only for non-last segments)
            if !isLast {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(separatorColor)
                    .padding(.horizontal, 7)
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

import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Individual breadcrumb segment with Xcode styling
struct BreadcrumbSegmentView: View {
    let segment: BreadcrumbSegment
    let isLast: Bool
    let onTap: () -> Void
    let onMenuTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false

    private var textColor: Color {
        if segment.isActive {
            return .primary
        }
        return .primary.opacity(0.8)
    }

    private var backgroundColor: Color {
        if isPressed {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color.accentColor.opacity(0.08)
        }
        return Color.clear
    }

    private var fontWeight: Font.Weight {
        segment.isActive ? .medium : .regular
    }

    var body: some View {
        HStack(spacing: 0) {
            // Segment content
            HStack(spacing: 6) {
                // Icon
                if let icon = segment.icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textColor)
                }

                // Text
                Text(segment.title)
                    .font(.system(size: 13, weight: fontWeight))
                    .foregroundStyle(textColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = true
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = false
                        }
                    }
            )

            // Menu arrow if segment has menu
            if segment.hasMenu && !isLast {
                Button(action: onMenuTap) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)
                        .padding(.trailing, 4)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.set()
                    }
                }
            }

            // Separator arrow (only for non-last segments)
            if !isLast {
                Text("›")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}
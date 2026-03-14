import SwiftUI

struct ExplorerSidebarRowChrome<Content: View>: View {
    enum Style {
        case plain
        case selectionPill
    }

    let isSelected: Bool
    let accentColor: Color
    var style: Style = .plain
    @ViewBuilder let content: () -> Content

    private var cornerRadius: CGFloat {
        style == .selectionPill ? 15 : SidebarRowConstants.hoverCornerRadius
    }

    @State private var isHovered = false
    @State private var isContextMenuVisible = false

    @ViewBuilder
    private var fill: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ColorTokens.accent.opacity(0.15))
        } else if isContextMenuVisible {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ColorTokens.Text.primary.opacity(0.08))
        } else if isHovered {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ColorTokens.Text.primary.opacity(0.06))
        } else {
            Color.clear
        }
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .padding(.horizontal, SpacingTokens.xxxs)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
                guard isHovered else { return }
                withAnimation(.easeInOut(duration: 0.1)) {
                    isContextMenuVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isContextMenuVisible = false
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

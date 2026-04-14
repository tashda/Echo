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

    @ViewBuilder
    private var fill: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ColorTokens.accent.opacity(0.15))
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
            .buttonStyle(.plain)
            .focusable(false)
            .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

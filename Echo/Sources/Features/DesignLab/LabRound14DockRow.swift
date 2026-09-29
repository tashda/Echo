#if DEBUG
import AppKit
import SwiftUI

/// A duotone symbol: the outline in its colour over its `.fill` variant at low opacity. Symbols
/// without a fill variant draw the outline only (a missing symbol would render as nothing).
struct LabDuotoneSymbol: View {
    let name: String
    let color: Color
    var mode: LabDockIconMode = .duotone
    var monoColor: Color = ColorTokens.Sidebar.symbol
    var font: Font = TypographyTokens.standard.weight(.light)

    private static let fillOpacity = 0.22

    var body: some View {
        ZStack {
            if mode == .duotone, NSImage(systemSymbolName: "\(name).fill", accessibilityDescription: nil) != nil {
                Image(systemName: "\(name).fill")
                    .foregroundStyle(color.opacity(Self.fillOpacity))
            }
            Image(systemName: name)
                .foregroundStyle(mode == .duotone ? color : monoColor)
        }
        .symbolRenderingMode(.monochrome)
        .font(font)
        .accessibilityHidden(true)
    }
}

/// One tree row with S4 Quiet's metrics (SidebarRowConstants), with duotone icons.
struct LabRound14DockRow: View {
    let node: LabDockNode
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let iconMode: LabDockIconMode
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            icon
                .frame(width: SidebarRowConstants.iconFrameWidth, height: SidebarRowConstants.iconFrameHeight)
            label
            Spacer(minLength: SpacingTokens.xxxs)
            if let count = node.count, count > 0 {
                Text("\(count)")
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .opacity(isHovering ? 1 : 0)
            }
        }
        .padding(.leading, SidebarRowConstants.rowLeadingPadding)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SpacingTokens.xxs2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(isSelected ? ColorTokens.Sidebar.selectedFill : isHovering ? ColorTokens.Sidebar.hoverFill : .clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous))
        .padding(.leading, CGFloat(depth) * SidebarRowConstants.indentStep)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(node.isFolder ? (isExpanded ? "Expanded" : "Collapsed") : "")
    }

    @ViewBuilder
    private var icon: some View {
        if node.isFolder && isHovering {
            Image(systemName: "chevron.right")
                .font(SidebarRowConstants.chevronFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        } else {
            LabDuotoneSymbol(name: node.symbol, color: isSelected ? ColorTokens.accent : node.color, mode: iconMode,
                             monoColor: isSelected ? ColorTokens.accent : ColorTokens.Sidebar.symbol)
        }
    }

    private var label: some View {
        Group {
            if let prefix = node.prefix {
                Text("\(Text("\(prefix).").foregroundStyle(ColorTokens.Text.tertiary))\(Text(node.title))")
            } else {
                Text(node.title)
            }
        }
        .font(TypographyTokens.standard)
        .foregroundStyle(ColorTokens.Text.primary)
        .lineLimit(1)
    }
}
#endif

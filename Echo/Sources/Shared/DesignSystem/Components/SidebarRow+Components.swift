import SwiftUI

extension SidebarRow {
    var densityIconFrameWidth: CGFloat {
        switch density {
        case .compact: return 14
        case .small: return 16
        case .medium: return 18
        case .large: return 20
        }
    }

    var densityIconFrameHeight: CGFloat {
        switch density {
        case .compact: return 12
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        }
    }

    var densityIconFont: Font {
        switch density {
        case .compact: return TypographyTokens.label.weight(.light)
        case .small: return TypographyTokens.detail.weight(.light)
        case .medium: return TypographyTokens.standard.weight(.light)
        case .large: return TypographyTokens.prominent.weight(.light)
        }
    }

    var densityLabelFont: Font {
        switch density {
        case .compact: return TypographyTokens.label
        case .small: return TypographyTokens.detail
        case .medium: return TypographyTokens.standard
        case .large: return Font.system(size: 15, weight: .regular)
        }
    }

    @ViewBuilder
    var iconView: some View {
        if showChevron && isHovering {
            Image(systemName: "chevron.right")
                .font(SidebarRowConstants.chevronFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .frame(width: densityIconFrameWidth, height: densityIconFrameHeight)
                .accessibilityHidden(true)
        } else {
            symbolView
        }
    }

    @ViewBuilder
    private var symbolView: some View {
        switch icon {
        case .system(let name):
            ZStack {
                // Duotone (IC2, design board 2026-09-30): the outline over its fill at low
                // opacity, for symbols that have a fill variant.
                if usesDuotoneIcons, let fill = SidebarDuotoneSymbols.fillName(for: name) {
                    Image(systemName: fill)
                        .foregroundStyle(resolvedIconColor.opacity(SidebarDuotoneSymbols.fillOpacity))
                }
                Image(systemName: name)
                    .foregroundStyle(resolvedIconColor)
            }
            .font(densityIconFont)
            .imageScale(.medium)
            .symbolRenderingMode(.monochrome)
            .frame(width: densityIconFrameWidth, height: densityIconFrameHeight)
        case .asset(let name):
            Image(name)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(resolvedIconColor)
                .frame(width: densityIconFrameWidth, height: densityIconFrameHeight)
        case .none:
            Color.clear.frame(width: densityIconFrameWidth, height: densityIconFrameHeight)
        }
    }
}

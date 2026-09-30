import SwiftUI

/// The section dock (round 16, H5): Xcode's navigator icons spread across a Liquid Glass capsule
/// as wide as the card, the current one in the accent colour with no fill. Rows scroll under it
/// and show through the glass, blurred. Sections left out sit under More (»). Right-click an
/// icon for its section's menu and Dock; right-click the empty capsule for Dock alone.
struct ExplorerDockRow: View {
    let connectionID: UUID
    let layout: ExplorerDockLayout
    let selectedID: String
    let style: SidebarDockIconStyle
    let accentColor: Color
    /// The tree's colourful-mode colour for a role colour, used by duotone icons.
    let duotoneColor: (Color) -> Color

    @Environment(\.sidebarDensity) private var density
    @Environment(\.explorerDockActions) private var actions

    private var capsuleHeight: CGFloat { LayoutTokens.ExplorerDock.capsuleHeight(for: density) }

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: SpacingTokens.none) {
                ForEach(layout.shown) { item in
                    button(item)
                }
                if !layout.overflow.isEmpty {
                    moreMenu
                }
            }
            .padding(.horizontal, SpacingTokens.xxs2)
            .frame(height: capsuleHeight)
            // Behind the icons, so an icon's own menu wins and the empty capsule gets Dock alone.
            .background {
                Color.clear.lazyContextMenu { actions.menu(connectionID, nil) }
            }
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .frame(maxHeight: .infinity)
    }

    private var iconFont: Font {
        switch density {
        case .compact: TypographyTokens.detail
        case .small: TypographyTokens.caption2
        case .medium: TypographyTokens.prominent
        case .large: TypographyTokens.displayMedium.weight(.regular)
        }
    }

    private func button(_ item: ExplorerDockItem) -> some View {
        let isCurrent = item.id == selectedID
        return Button { actions.select(connectionID, item.id) } label: {
            symbol(item, isCurrent: isCurrent)
                .frame(maxWidth: .infinity)
                .frame(height: capsuleHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .lazyContextMenu { actions.menu(connectionID, item.id) }
        .help(item.count.map { "\(item.title) · \($0)" } ?? item.title)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    /// Mono: grey, the current one in the accent colour. Duotone: the tree's colours.
    private func symbol(_ item: ExplorerDockItem, isCurrent: Bool) -> some View {
        let tint = isCurrent ? accentColor : (style == .duotone ? duotoneColor(item.color) : ColorTokens.Sidebar.symbol)
        return ZStack {
            if style == .duotone, let fill = SidebarDuotoneSymbols.fillName(for: item.symbol) {
                Image(systemName: fill).foregroundStyle(tint.opacity(SidebarDuotoneSymbols.fillOpacity))
            }
            Image(systemName: item.symbol).foregroundStyle(tint)
        }
        .symbolRenderingMode(.monochrome)
        .font(iconFont)
        .accessibilityHidden(true)
    }

    /// The sections left out of the capsule. The chevrons take the accent colour while one of
    /// them is the section shown.
    private var moreMenu: some View {
        let showsOverflow = layout.overflow.contains { $0.id == selectedID }
        return Menu {
            ForEach(layout.overflow) { item in
                Button { actions.select(connectionID, item.id) } label: {
                    Label(item.title, systemImage: item.symbol)
                }
            }
        } label: {
            Image(systemName: "chevron.right.2")
                .font(iconFont.weight(.semibold))
                .foregroundStyle(showsOverflow ? accentColor : ColorTokens.Text.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(minWidth: capsuleHeight, minHeight: capsuleHeight)
        .help("More sections")
        .accessibilityLabel("More sections")
    }
}

import SwiftUI

/// The section dock (rounds 16 and 19): Xcode's navigator icons spread across a Liquid Glass
/// capsule as wide as the card, with a hairline edge and a soft shadow (C5). Icons are medium
/// weight, the current one in the accent colour; a hovered icon grows slightly. Sections the
/// capsule leaves out are listed by More (»), a section of its own. Right-click an icon for its
/// section's menu and Dock; right-click the empty capsule for Dock alone.
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
    private var moreID: String { ExplorerDock.moreItemID(connectionID) }

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: SpacingTokens.none) {
                ForEach(layout.shown) { item in
                    ExplorerDockButton(
                        title: item.count.map { "\(item.title) · \($0)" } ?? item.title,
                        isCurrent: item.id == selectedID,
                        font: iconFont,
                        height: capsuleHeight,
                        action: { actions.select(connectionID, item.id) }
                    ) {
                        symbol(item, isCurrent: item.id == selectedID)
                    }
                    .lazyContextMenu { actions.menu(connectionID, item.id) }
                }
                if !layout.overflow.isEmpty {
                    ExplorerDockButton(title: "More sections", isCurrent: selectedID == moreID, font: iconFont, height: capsuleHeight,
                                       action: { actions.select(connectionID, moreID) }) {
                        Image(systemName: "chevron.right.2")
                            .foregroundStyle(selectedID == moreID ? accentColor : ColorTokens.Text.secondary)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.xxs2)
            .frame(height: capsuleHeight)
            // Behind the icons, so an icon's own menu wins and the empty capsule gets Dock alone.
            .background {
                Color.clear.lazyContextMenu { actions.menu(connectionID, nil) }
            }
            .glassEffect(.regular, in: .capsule)
            // C5: an edge and a soft shadow keep the glass visible over a white card.
            .overlay(Capsule().strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.ExplorerDock.edgeOpacity),
                                            lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
            .shadow(color: .black.opacity(LayoutTokens.ExplorerDock.shadowOpacity), radius: SpacingTokens.xxs, y: SpacingTokens.micro)
        }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .frame(maxHeight: .infinity)
    }

    /// Medium weight (round 19), sized by the sidebar size.
    private var iconFont: Font {
        let font: Font = switch density {
        case .compact: TypographyTokens.detail
        case .small: TypographyTokens.caption2
        case .medium: TypographyTokens.prominent
        case .large: TypographyTokens.displayMedium
        }
        return font.weight(.medium)
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
    }
}

/// One slot in the dock: an equal share of the capsule, the whole slot clickable. A hovered icon
/// that isn't the current one grows slightly (round 19).
struct ExplorerDockButton<Label: View>: View {
    let title: String
    let isCurrent: Bool
    let font: Font
    let height: CGFloat
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovering = false
    @Environment(\.echoMotion) private var motion

    var body: some View {
        Button(action: action) {
            label()
                .font(font)
                .scaleEffect(isHovering && !isCurrent ? LayoutTokens.ExplorerDock.hoverScale : 1)
                .animation(motion.hover, value: isHovering)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

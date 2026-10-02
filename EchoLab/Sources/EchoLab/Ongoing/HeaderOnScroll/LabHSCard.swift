import SwiftUI

/// A card with a long list of databases and a banner header that behaves as round 57's choice says.
/// Scroll it: the lab reads the scroll offset and places the name block and the icon menu from it.
struct LabHSCard: View {
    let look: LabHSLook
    let server: LabSHServer
    @State private var offset: CGFloat = 0
    @State private var section = LabHRSection.databases
    @Environment(\.colorScheme) private var scheme

    private let nameHeight: CGFloat = 60
    private let dockHeight: CGFloat = 40
    private var fullHeight: CGFloat { nameHeight + dockHeight }
    private var tint: Color { server.color }
    private var rows: [String] { (1...34).map { "Database \($0)" } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: SpacingTokens.none) {
                    Color.clear.frame(height: fullHeight + SpacingTokens.xxs)
                    ForEach(rows, id: \.self) { LabSHRow(title: $0) }
                }
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, new in offset = max(0, new) }
            blocks
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .workspaceCard()
    }

    // MARK: Blocks

    private var o: CGFloat { offset }

    /// The name block's top and height, and the menu's top and opacity, from the scroll offset.
    private var geometry: (nameY: CGFloat, nameH: CGFloat, dockY: CGFloat, dockOpacity: Double, pinned: Bool, chip: Double, dockPinned: Bool) {
        let slim = look.slim.height
        switch look.behaviour {
        case .pinned, .rounded:
            return (0, nameHeight, nameHeight, 1, true, 0, false)
        case .collapse:
            let menuGone = min(o, dockHeight)
            let shrink = min(max(o - dockHeight, 0), nameHeight - slim)
            return (0, nameHeight - shrink, nameHeight - menuGone, 1 - Double(menuGone / dockHeight), o > 0, 0, false)
        case .follow:
            let leave = max(o - dockHeight - 30, 0)
            return (-leave, nameHeight, nameHeight - min(o, dockHeight), 1 - Double(min(o, dockHeight) / dockHeight), o > 0, 0, false)
        case .away:
            return (-o, nameHeight, nameHeight - o, 1, false, 0, false)
        case .menu:
            return (-o, nameHeight, max(0, nameHeight - o), 1, o > 0, 0, true)
        case .chip:
            let chip = Double(min(max((o - fullHeight * 0.4) / (fullHeight * 0.4), 0), 1))
            return (-o, nameHeight, nameHeight - o, 1, false, chip, false)
        }
    }

    @ViewBuilder
    private var blocks: some View {
        let g = geometry
        let radius = look.edge.radius
        ZStack(alignment: .topLeading) {
            // The menu, under the name block.
            if look.behaviour != .chip || g.chip < 1 {
                dockBlock(height: look.behaviour == .menu ? dockHeight - (dockHeight - look.slim.height) * min(max(o / nameHeight, 0), 1) : dockHeight)
                    .opacity(g.dockOpacity)
                    .offset(y: g.dockY)
            }
            nameBlock(height: g.nameH, rounded: g.pinned || look.behaviour == .rounded)
                .offset(y: g.nameY)
                .opacity(look.behaviour == .menu && o > nameHeight ? 0 : 1)
            if look.behaviour == .chip, g.chip > 0 { chip.opacity(g.chip) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(true)
        .shadow(color: .black.opacity(look.under == .shadow && g.pinned ? 0.2 : 0), radius: SpacingTokens.xs, y: SpacingTokens.xxxs * 2)
        .animation(nil, value: radius)
    }

    private func bannerShape(_ rounded: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(bottomLeadingRadius: rounded ? look.edge.radius : 0, bottomTrailingRadius: rounded ? look.edge.radius : 0, style: .continuous)
    }

    private var banner: some ShapeStyle {
        LinearGradient(colors: [tint.opacity(0.92), tint], startPoint: .top, endPoint: .bottom)
    }

    private func nameBlock(height: CGFloat, rounded: Bool) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Text(section.title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(ColorTokens.Text.onFill.opacity(0.82))
            Text(server.name).font(.system(size: 22, weight: .semibold)).foregroundStyle(ColorTokens.Text.onFill)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .leading)
        .frame(height: max(height, 0), alignment: .center)
        .background(banner, in: bannerShape(rounded))
        .background { if look.under == .blur, rounded { Rectangle().fill(.ultraThinMaterial).blur(radius: 6).padding(.bottom, -8) } }
        .clipped()
        .overlay(alignment: .bottom) { if rounded { Color.white.opacity(0.3).frame(height: 0.5) } }
    }

    private func dockBlock(height: CGFloat) -> some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(LabHRSection.allCases, id: \.self) { item in
                Image(systemName: item.symbol)
                    .symbolVariant(item == section ? .fill : .none)
                    .font(.system(size: 15, weight: item == section ? .bold : .medium))
                    .foregroundStyle(ColorTokens.Text.onFill.opacity(item == section ? 1 : 0.72))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { section = item }
            }
        }
        .padding(.horizontal, SpacingTokens.xs2)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(banner)
    }

    private var chip: some View {
        Text(server.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(ColorTokens.Text.onFill)
            .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg + SpacingTokens.xxs)
            .background(tint, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: SpacingTokens.xxs, y: SpacingTokens.xxxs)
            .padding(SpacingTokens.xs)
    }
}

/// The tree's column with a card in it.
struct LabHSColumn<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.Workspace.canvas)
    }
}

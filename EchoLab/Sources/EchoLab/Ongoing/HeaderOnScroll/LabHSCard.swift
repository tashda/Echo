import SwiftUI

/// A card with a long list of databases and a banner header that behaves as round 57's choice says.
/// Scroll it: the lab reads the scroll offset and places the header and the icon menu from it, so
/// the menu morphs continuously from the banner's row into its pinned form.
struct LabHSCard: View {
    let look: LabHSLook
    let server: LabSHServer
    @State private var offset: CGFloat = 0
    @State private var section = LabHRSection.databases
    @State private var width: CGFloat = 340

    private let nameHeight: CGFloat = 60
    private let dockHeight: CGFloat = 40
    private let pillHeight: CGFloat = 30
    private let pillTop: CGFloat = 8
    private var fullHeight: CGFloat { nameHeight + dockHeight }
    private var tint: Color { server.color }
    private var rows: [String] { (1...34).map { "Database \($0)" } }
    private var o: CGFloat { offset }

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
            if look.behaviour == .pinned { pinnedBanner } else { scrolling }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GeometryReader { proxy in Color.clear.onAppear { width = proxy.size.width }.onChange(of: proxy.size.width) { _, new in width = new } })
        .workspaceCard()
    }

    // MARK: Pieces

    private var banner: LinearGradient { LinearGradient(colors: [tint.opacity(0.92), tint], startPoint: .top, endPoint: .bottom) }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Text(section.title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(ColorTokens.Text.onFill.opacity(0.82))
            Text(server.name).font(.system(size: 22, weight: .semibold)).foregroundStyle(ColorTokens.Text.onFill)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: nameHeight)
        .background(banner)
    }

    private func icons(color: Color) -> some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(LabHRSection.allCases, id: \.self) { item in
                Image(systemName: item.symbol)
                    .symbolVariant(item == section ? .fill : .none)
                    .font(.system(size: 15, weight: item == section ? .bold : .medium))
                    .foregroundStyle(color.opacity(item == section ? 1 : 0.72))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { section = item }
            }
        }
    }

    // MARK: Today

    private var pinnedBanner: some View {
        VStack(spacing: SpacingTokens.none) {
            nameBlock
            icons(color: ColorTokens.Text.onFill).padding(.horizontal, SpacingTokens.xs2).frame(height: dockHeight).background(banner)
        }
    }

    // MARK: The new behaviours

    private func mix(_ p: Double) -> Color {
        look.material == .banner ? ColorTokens.Text.onFill : ColorTokens.Text.onFill.mix(with: ColorTokens.Text.primary, by: p)
    }

    private var scrolling: some View {
        let behaviour = look.behaviour
        let pillMode = behaviour.isPill
        let p = Double(min(max(o / (pillMode ? nameHeight - pillTop : nameHeight), 0), 1))
        let top = pillMode ? max(pillTop, nameHeight - o) : max(0, nameHeight - o)
        let target: CGFloat = pillMode ? pillHeight : look.slim.height
        let height = dockHeight + (target - dockHeight) * CGFloat(p)
        let pillWidth: CGFloat = behaviour == .pillName ? 270 : 190
        let barWidth = pillMode ? width + (pillWidth - width) * CGFloat(p) : width
        let radius = pillMode ? CGFloat(p) * height / 2 : (o > 0 ? look.edge.radius * CGFloat(min(p * 2, 1)) : 0)
        let showsName = behaviour.hasName
        return ZStack(alignment: .topLeading) {
            nameBlock.offset(y: -o)
            // The menu: a block that is the banner's row at first, then the pinned bar or pill.
            ZStack {
                menuSurface(p: p, radius: radius, height: height)
                HStack(spacing: SpacingTokens.none) {
                    if showsName && behaviour != .chips {
                        Text(server.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(mix(p)).lineLimit(1)
                            .padding(.leading, SpacingTokens.sm).opacity(p).frame(width: pillMode ? 0.4 * barWidth : 0.42 * barWidth, alignment: .leading)
                    }
                    icons(color: mix(p)).padding(.horizontal, pillMode ? SpacingTokens.xs : SpacingTokens.xs2)
                }
            }
            .frame(width: barWidth, height: height)
            .shadow(color: .black.opacity(look.under == .shadow && o > 0 ? 0.22 : 0), radius: SpacingTokens.xs, y: SpacingTokens.xxxs * 2)
            .offset(x: pillMode ? (behaviour == .chips ? (width - barWidth - SpacingTokens.xs * CGFloat(p)) : (width - barWidth) / 2) : 0, y: top)
            if behaviour == .chips {
                Text(server.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                    .padding(.horizontal, SpacingTokens.sm).frame(height: pillHeight)
                    .glassEffect(look.material == .tinted ? .regular.tint(tint.opacity(0.35)) : .regular, in: .capsule)
                    .opacity(p).offset(x: SpacingTokens.xs, y: top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The surface behind the menu: the banner's colour at first; with a pill it clears into the chosen material.
    @ViewBuilder
    private func menuSurface(p: Double, radius: CGFloat, height: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: look.behaviour.isPill ? radius : 0, bottomLeadingRadius: radius,
                                           bottomTrailingRadius: radius, topTrailingRadius: look.behaviour.isPill ? radius : 0, style: .continuous)
        if look.behaviour.isPill, look.material != .banner {
            ZStack {
                shape.fill(banner).opacity(1 - p)
                Color.clear
                    .glassEffect(look.material == .tinted ? .regular.tint(tint.opacity(0.35)) : .regular, in: .rect(cornerRadius: max(radius, 0.1), style: .continuous))
                    .opacity(p)
            }
        } else {
            shape.fill(banner)
        }
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

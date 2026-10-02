import SwiftUI

/// Three cards in the tree's scroll view, each with a banner header pinned from its own scroll position
/// (round 57). The header is drawn in an overlay from the scroll offset and each card's frame, so
/// the menu morphs continuously, is pushed out by the next card, and comes back when an icon is clicked.
struct LabHOTree: View {
    let look: LabHSLook
    let handover: LabHOHandover
    let overlap: Bool
    private let servers: [LabSHServer] = [.production, .test, .development]
    private let counts = [30, 8, 16, 10, 6]
    @State private var offset: CGFloat = 0
    @State private var frames: [Int: CGRect] = [:]
    @State private var sections: [Int: LabHRSection] = [:]
    @State private var thresholdP: [Int: CGFloat] = [:]
    @State private var reveal: [Int: CGFloat] = [:]
    @State private var viewport: CGFloat = 520

    private let nameH: CGFloat = 60
    private let dockH: CGFloat = 40
    private let pillH: CGFloat = 30
    private let pillTop: CGFloat = 8
    private var headerH: CGFloat { nameH + dockH }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(spacing: overlap ? -SpacingTokens.sm2 : SpacingTokens.xs) {
                        ForEach(servers.indices, id: \.self) { index in card(index).id("card-\(index)").zIndex(Double(index)) }
                    }
                    .padding(SpacingTokens.sm)
                    .coordinateSpace(name: "ho-content")
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, new in
                    offset = max(0, new)
                    updateThresholds()
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
                ZStack(alignment: .topLeading) {
                    ForEach(servers.indices, id: \.self) { index in
                        if let frame = frames[index] { header(index, frame: frame, proxy: proxy) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            }
        }
        .onPreferenceChange(LabHOFrames.self) { frames = $0 }
        .background(ColorTokens.Workspace.canvas)
    }

    // MARK: Cards

    private func section(_ index: Int) -> LabHRSection { sections[index] ?? .databases }

    private func card(_ index: Int) -> some View {
        let current = section(index)
        let count = counts[current.rawValue]
        return VStack(spacing: SpacingTokens.none) {
            Color.clear.frame(height: headerH + SpacingTokens.xxs)
            VStack(spacing: SpacingTokens.none) {
                ForEach(0..<count, id: \.self) { LabSHRow(title: "\(current.title) \($0 + 1)", symbol: current.symbol) }
            }
            .id(current)
            .transition(look.click == .fade ? .opacity : .identity)
            .padding(.bottom, SpacingTokens.xxs)
        }
        .frame(maxWidth: .infinity)
        .workspaceCard()
        .shadow(color: .black.opacity(overlap ? 0.18 : 0), radius: SpacingTokens.xs, y: -SpacingTokens.xxxs)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: LabHOFrames.self, value: [index: proxy.frame(in: .named("ho-content"))])
        })
        .animation(.smooth(duration: 0.35), value: current)
    }

    // MARK: Header

    private var tintFor: (Int) -> Color { { servers[$0].color } }

    /// How far the card's top is above the viewport's top; the reveal keeps a collapsed look alive while it plays.
    private func q(_ index: Int, _ frame: CGRect) -> CGFloat { max(offset - frame.minY, reveal[index] ?? -1000) }

    private func updateThresholds() {
        guard look.morph == .springs else { return }
        for (index, frame) in frames {
            let target: CGFloat = (offset - frame.minY) > 24 ? 1 : 0
            if thresholdP[index] != target {
                withAnimation(look.feel.animation) { thresholdP[index] = target }
            }
        }
    }

    @ViewBuilder
    private func header(_ index: Int, frame: CGRect, proxy: ScrollViewProxy) -> some View {
        let q = q(index, frame)
        let tint = tintFor(index)
        if look.isToday {
            todayHeader(index, frame: frame, q: q, tint: tint, proxy: proxy)
        } else {
            movingHeader(index, frame: frame, q: q, tint: tint, proxy: proxy)
        }
    }

    private var bannerFill: (Color) -> LinearGradient { { LinearGradient(colors: [$0.opacity(0.92), $0], startPoint: .top, endPoint: .bottom) } }

    private func nameBlock(_ index: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Text(section(index).title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.3)
                .foregroundStyle(ColorTokens.Text.onFill.opacity(0.82))
            Text(servers[index].name).font(.system(size: 22, weight: .semibold)).foregroundStyle(ColorTokens.Text.onFill)
        }
        .padding(.horizontal, SpacingTokens.sm).frame(maxWidth: .infinity, alignment: .leading).frame(height: nameH)
        .background(bannerFill(tint))
    }

    private func icons(_ index: Int, color: Color, selectedColor: Color? = nil, proxy: ScrollViewProxy) -> some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(LabHRSection.allCases, id: \.self) { item in
                let isSelected = item == section(index)
                Image(systemName: item.symbol).symbolVariant(isSelected ? .fill : .none)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundStyle((isSelected ? (selectedColor ?? color) : color).opacity(isSelected ? 1 : 0.72))
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                    .onTapGesture { choose(item, in: index, proxy: proxy) }
            }
        }
    }

    /// Echo today: the banner pinned whole, a hard edge, until the card's end pushes it out.
    private func todayHeader(_ index: Int, frame: CGRect, q: CGFloat, tint: Color, proxy: ScrollViewProxy) -> some View {
        let top = max(0, -q)
        let limit = frame.maxY - offset - headerH
        return VStack(spacing: SpacingTokens.none) {
            nameBlock(index, tint)
            icons(index, color: ColorTokens.Text.onFill, proxy: proxy).frame(height: dockH).padding(.horizontal, SpacingTokens.xs2).background(bannerFill(tint))
        }
        .frame(width: frame.width)
        .offset(x: frame.minX, y: min(top, limit))
    }

    private func movingHeader(_ index: Int, frame: CGRect, q: CGFloat, tint: Color, proxy: ScrollViewProxy) -> some View {
        let form = look.form
        let pill = form.isPill
        let dist = pill ? nameH - pillTop : nameH
        let continuous = Double(min(max(q / dist, 0), 1))
        let p = look.morph == .follows ? continuous : Double(thresholdP[index] ?? 0)
        let pinnedTop: CGFloat = pill ? pillTop : 0
        let target: CGFloat = pill ? pillH : look.slim.height
        let height = dockH + (target - dockH) * CGFloat(p)
        let naturalY = max(pinnedTop, nameH - q)
        let endY = (frames[index + 1]?.minY ?? frame.maxY) - offset
        let limit = endY - height - SpacingTokens.xs
        let gapTo = endY - (naturalY + height)
        var y = naturalY
        var fade = 1.0
        var scale: CGFloat = 1
        var chip = 0.0
        var clipTo: CGFloat? = nil
        switch handover {
        case .push:
            y = min(naturalY, limit)
        case .fade:
            fade = Double(min(max(gapTo / 40, 0), 1))
        case .overtaken:
            clipTo = max(0, endY - naturalY)
        case .squash:
            y = min(naturalY, limit)
            let d = Double(min(max((naturalY - limit) / height, 0), 1))
            scale = 1 - 0.18 * CGFloat(d)
            fade = 1 - 0.7 * d
        case .chip:
            chip = Double(min(max((90 - gapTo) / 90, 0), 1))
            clipTo = max(0, endY - naturalY)
        }
        let basePill: CGFloat = form == .pillName ? 270 : 190
        let pillWidth: CGFloat = basePill + (130 - basePill) * CGFloat(handover == .chip ? chip : 0)
        let width = pill ? frame.width + (pillWidth - frame.width) * CGFloat(p) : frame.width
        let radius: CGFloat = pill ? CGFloat(p) * height / 2 : 14 * CGFloat(p)
        let xShift: CGFloat = {
            guard pill else { return 0 }
            switch look.position {
            case .centre: return (frame.width - width) / 2
            case .leading: return SpacingTokens.xs * CGFloat(p)
            case .trailing: return frame.width - width - SpacingTokens.xs * CGFloat(p)
            }
        }()
        let iconColor: Color = look.material == .banner || !pill
            ? ColorTokens.Text.onFill : ColorTokens.Text.onFill.mix(with: ColorTokens.Text.primary, by: p)
        return ZStack(alignment: .topLeading) {
            if q < nameH + 20 { nameBlock(index, tint).frame(width: frame.width).offset(x: frame.minX, y: -q) }
            ZStack {
                surface(tint: tint, p: p, radius: radius, pill: pill)
                HStack(spacing: SpacingTokens.none) {
                    if form.hasName {
                        Text(servers[index].name).font(.system(size: 13, weight: .semibold)).foregroundStyle(iconColor).lineLimit(1)
                            .padding(.leading, SpacingTokens.sm).opacity(p).frame(width: 0.4 * width, alignment: .leading)
                    }
                    icons(index, color: iconColor, selectedColor: look.material == .surface && pill ? tint : nil, proxy: proxy)
                        .padding(.horizontal, pill ? SpacingTokens.xs : SpacingTokens.xs2)
                        .opacity(1 - chip)
                }
                if chip > 0 {
                    Text(servers[index].name).font(.system(size: 13, weight: .semibold)).foregroundStyle(iconColor).lineLimit(1).opacity(chip)
                }
            }
            .frame(width: width, height: height)
            .scaleEffect(scale)
            .mask(alignment: .top) { Rectangle().frame(height: clipTo.map { max($0, 0) } ?? height + 40).padding(.top, 0) }
            .shadow(color: .black.opacity(p > 0.5 && (look.material != .glass || !pill) ? 0.2 : 0), radius: SpacingTokens.xs, y: SpacingTokens.xxxs * 2)
            .offset(x: frame.minX + xShift, y: y)
            .opacity(fade)
        }
    }

    /// The surface behind the menu: the banner's colour at first, then the chosen material.
    @ViewBuilder
    private func surface(tint: Color, p: Double, radius: CGFloat, pill: Bool) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: pill ? radius : 0, bottomLeadingRadius: radius, bottomTrailingRadius: radius,
                                           topTrailingRadius: pill ? radius : 0, style: .continuous)
        if pill {
            switch look.material {
            case .glass:
                ZStack {
                    shape.fill(bannerFill(tint)).opacity(1 - p)
                    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: max(radius, 0.1), style: .continuous)).opacity(p)
                }
            case .banner:
                shape.fill(bannerFill(tint))
            case .frosted:
                ZStack {
                    shape.fill(bannerFill(tint)).opacity(1 - p)
                    shape.fill(.regularMaterial).opacity(p)
                    shape.strokeBorder(ColorTokens.Text.primary.opacity(0.12 * p), lineWidth: 0.5)
                }
            case .surface:
                ZStack {
                    shape.fill(bannerFill(tint)).opacity(1 - p)
                    shape.fill(ColorTokens.Workspace.card).opacity(p)
                }
            }
        } else {
            shape.fill(bannerFill(tint))
        }
    }

    // MARK: Clicking an icon

    /// The section changes; what the scroll and the header do next is the click behaviour.
    private func choose(_ item: LabHRSection, in index: Int, proxy: ScrollViewProxy) {
        guard let frame = frames[index] else { return }
        let scrolled = offset - frame.minY
        let id = "card-\(index)"
        let scale = look.speed.scale
        switch look.click {
        case .stay:
            withAnimation(.smooth(duration: 0.35)) { sections[index] = item }
        case .snap:
            sections[index] = item
            proxy.scrollTo(id, anchor: .top)
        case .smooth, .fade:
            withAnimation(.smooth(duration: 0.55 * scale)) {
                sections[index] = item
                proxy.scrollTo(id, anchor: .top)
            }
        case .reveal:
            sections[index] = item
            if scrolled > 0 { reveal[index] = scrolled }
            proxy.scrollTo(id, anchor: .top)
            if scrolled > 0 {
                withAnimation(look.feel.animation.speed(1 / scale), completionCriteria: .logicallyComplete) {
                    reveal[index] = 0
                } completion: {
                    reveal[index] = nil
                }
            }
        }
    }
}

/// Each card's frame in the tree's content, for the header overlay.
struct LabHOFrames: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

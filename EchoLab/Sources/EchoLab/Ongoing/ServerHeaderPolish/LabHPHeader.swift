import SwiftUI

/// The top of a server card in one of round 50's designs. Colour that fills (ink, enamel, duotone,
/// wash, aurora) is `LabHPBackdrop`, painted by the card behind the header, or behind the header and
/// the dock; everything inset (tile, slab, badge, chips) is drawn here.
struct LabHPHeader: View {
    let server: LabSHServer
    let look: LabHPLook
    var section = "Databases"
    var showsChevron = false
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    private var palette: LabHPPalette { LabHPPalette(tint: server.color, strength: look.strength) }
    private var design: LabHPDesign { look.design }
    private var nameColor: AnyShapeStyle {
        design.isOnFill ? AnyShapeStyle(ColorTokens.Text.onFill) : AnyShapeStyle(ColorTokens.Text.primary)
    }

    var body: some View {
        if let spec = design.spec {
            LabHQHeaderView(server: server, look: look, spec: spec, design: design, section: section, showsChevron: showsChevron)
        } else {
            drawn
        }
    }

    private var drawn: some View {
        content
            .padding(.horizontal, design == .slab ? SpacingTokens.xxs1 : SpacingTokens.sm)
            .padding(.top, design == .slab ? SpacingTokens.xxs1 : SpacingTokens.sm)
            .padding(.bottom, design.padsBelow ? (design == .slab ? SpacingTokens.xxs1 : SpacingTokens.sm) : SpacingTokens.none)
    }

    @ViewBuilder
    private var content: some View {
        switch design {
        case .eyebrow: eyebrow
        case .tile: tile
        case .slab: slab
        case .badge: row { badge }
        case .numeral: row { numeral }
        case .underline: underline
        case .chips: chips
        default: row { EmptyView() }
        }
    }

    // MARK: Pieces

    /// Name and second line on the left, optional trailing content, the chevron.
    private func row<Trailing: View>(@ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs) {
            lines
            Spacer(minLength: SpacingTokens.xxs)
            trailing()
            chevron
        }
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            nameText
            secondLine
        }
    }

    private var nameText: some View {
        Text(server.name).font(look.face.font).foregroundStyle(nameColor).lineLimit(1)
    }

    @ViewBuilder
    private var secondLine: some View {
        let secondary: AnyShapeStyle = design.isOnFill ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.78)) : AnyShapeStyle(ColorTokens.Text.tertiary)
        switch look.line {
        case .today:
            Text("\(server.product) · \(section)").font(SidebarRowConstants.trailingFont).foregroundStyle(secondary).lineLimit(1)
        case .caps:
            Text(server.productCaps).font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(secondary).lineLimit(1)
        case .host:
            Text(server.host).font(TypographyTokens.detailMono).foregroundStyle(secondary).lineLimit(1)
        case .none:
            EmptyView()
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(SidebarRowConstants.sectionChevronFont)
            .foregroundStyle(design.isOnFill ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.85)) : AnyShapeStyle(ColorTokens.Text.tertiary))
            .opacity(showsChevron ? 1 : 0)
    }

    // MARK: Designs

    /// HP4: the product above the name, in the colour.
    private var eyebrow: some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(server.productCaps)
                    .font(.system(size: 10, weight: .semibold)).tracking(0.9)
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                nameText
                if look.line == .host {
                    Text(server.host).font(TypographyTokens.detailMono).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                }
            }
            Spacer(minLength: SpacingTokens.xxs)
            chevron
        }
    }

    /// HP5: the engine's symbol on a tinted tile.
    private var tile: some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs2) {
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                .fill(palette.soft(0.2))
                .overlay {
                    RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                        .strokeBorder(palette.soft(0.4), lineWidth: 0.5)
                }
                .overlay {
                    Image(systemName: "cylinder.split.1x2.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.ink)
                }
                .frame(width: SpacingTokens.xl, height: SpacingTokens.xl)
            lines
            Spacer(minLength: SpacingTokens.xxs)
            chevron
        }
    }

    /// HP7: the lines on one inset glass panel, concentric with the card.
    private var slab: some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs) {
            lines
            Spacer(minLength: SpacingTokens.xxs)
            chevron
        }
        .padding(.horizontal, SpacingTokens.xs2)
        .padding(.vertical, SpacingTokens.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(palette.soft(0.26)),
                     in: .rect(cornerRadius: max(cornerRadius - SpacingTokens.xxs1, SpacingTokens.xxs2), style: .continuous))
    }

    /// HP9: the environment label.
    private var badge: some View {
        Text(server.environmentLabel)
            .font(.system(size: 10, weight: .bold)).tracking(0.7)
            .foregroundStyle(palette.ink)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(palette.soft(0.16), in: Capsule())
    }

    /// HP10: the version as a mark.
    private var numeral: some View {
        Text(server.versionNumeral)
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(palette.ink.opacity(0.9))
            .padding(.trailing, SpacingTokens.xxs)
    }

    /// HP11: a short accent between the name and the second line.
    private var underline: some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                nameText
                Capsule().fill(palette.ink).frame(width: SpacingTokens.lg - SpacingTokens.xxs1 * 0.4, height: SpacingTokens.xxxs1)
                secondLine
            }
            Spacer(minLength: SpacingTokens.xxs)
            chevron
        }
    }

    /// HP12: name, then tokens.
    private var chips: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(alignment: .center, spacing: SpacingTokens.xs) {
                nameText
                Spacer(minLength: SpacingTokens.xxs)
                chevron
            }
            HStack(spacing: SpacingTokens.xxs) {
                chip(dot: ColorTokens.Status.success, text: "Connected")
                chip(dot: nil, text: server.versionNumeral)
                chip(dot: nil, text: server.latency)
            }
        }
    }

    private func chip(dot: Color?, text: String) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            if let dot { Circle().fill(dot).frame(width: SpacingTokens.xxs, height: SpacingTokens.xxs) }
            Text(text).font(.system(size: 10.5, weight: .medium)).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxxs)
        .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())
    }
}

/// Colour painted behind the header, or behind the header and the dock. The card clips it to its corners.
struct LabHPBackdrop: View {
    let design: LabHPDesign
    let palette: LabHPPalette

    var body: some View {
        switch design {
        case .wash:
            LinearGradient(colors: [palette.soft(0.2), palette.soft(0)], startPoint: .top, endPoint: .bottom)
        case .ink:
            palette.deep
        case .enamel:
            palette.deep
                .overlay {
                    LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0)], startPoint: .top, endPoint: .center)
                }
                .overlay(alignment: .top) { Color.white.opacity(0.28).frame(height: 0.5) }
                .overlay(alignment: .bottom) { Color.black.opacity(0.18).frame(height: 0.5) }
        case .duotone:
            LinearGradient(colors: [palette.neighbour.mix(with: .black, by: palette.strength == .vivid ? 0.05 : 0.3),
                                    palette.deep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .aurora:
            MeshGradient(width: 3, height: 3,
                         points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.55, 0.45], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                         colors: [palette.soft(0.5), palette.neighbour.opacity(0.28 * palette.strength.opacityScale), palette.otherNeighbour.opacity(0.4 * palette.strength.opacityScale),
                                  palette.soft(0.3), palette.soft(0.18), palette.neighbour.opacity(0.14 * palette.strength.opacityScale),
                                  palette.soft(0.04), palette.soft(0.02), palette.soft(0.0)])
        default:
            LabHQBackdrop(design: design, palette: palette)
        }
    }
}

/// The section dock, with a hint of the server's colour when asked.
struct LabHPDockBar: View {
    let look: LabHPLook
    let palette: LabHPPalette
    private let symbols = ["cylinder", "shield", "square.grid.2x2", "clock", "gearshape"]

    private var current: Color {
        look.coversDock && look.design.isOnFill ? Color.white : (look.design == .wash ? palette.tint : ColorTokens.accent)
    }

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                Image(systemName: symbol)
                    .font(TypographyTokens.prominent.weight(.medium))
                    .foregroundStyle(index == 0 ? AnyShapeStyle(current) : AnyShapeStyle(ColorTokens.Sidebar.symbol))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, SpacingTokens.xxs2)
        .frame(height: SpacingTokens.lg + SpacingTokens.xxs)
        .glassEffect(look.dock == .tinted ? .regular.tint(palette.soft(0.16)) : .regular, in: .capsule)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
    }
}

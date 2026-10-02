import SwiftUI

/// Round 50, revision 2: draws any header composed as a `LabHQSpec`.
struct LabHQHeaderView: View {
    let server: LabSHServer
    let look: LabHPLook
    let spec: LabHQSpec
    let design: LabHPDesign
    var section = "Databases"
    var showsChevron = false
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    private var palette: LabHPPalette { LabHPPalette(tint: server.color, strength: look.strength) }
    private var onFill: Bool { spec.surface.isOnFill }
    private var primary: AnyShapeStyle { onFill ? AnyShapeStyle(ColorTokens.Text.onFill) : AnyShapeStyle(ColorTokens.Text.primary) }
    private var tertiary: AnyShapeStyle { onFill ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.78)) : AnyShapeStyle(ColorTokens.Text.tertiary) }
    private var nameFont: Font { spec.fixedFace ? .system(size: 14, weight: .semibold) : look.face.font }

    var body: some View {
        surfaced
    }

    // MARK: Surface

    @ViewBuilder
    private var surfaced: some View {
        switch spec.surface {
        case .tab:
            row
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.top, SpacingTokens.sm + SpacingTokens.xs2)
                .overlay(alignment: .topLeading) { tab.padding(.leading, SpacingTokens.sm) }
        case .ruleUnder:
            row
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.top, SpacingTokens.sm)
                .padding(.bottom, SpacingTokens.xs)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(LinearGradient(colors: [palette.ink, palette.ink.opacity(0)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: SpacingTokens.xxxs1 * 0.6)
                        .padding(.horizontal, SpacingTokens.sm)
                }
        case .insetBanner:
            row
                .padding(.horizontal, SpacingTokens.xs2)
                .padding(.vertical, SpacingTokens.xs)
                .background(RoundedRectangle(cornerRadius: max(cornerRadius - SpacingTokens.xxs1, SpacingTokens.xxs2), style: .continuous)
                    .fill(LinearGradient(colors: [palette.deep.opacity(0.92), palette.deep], startPoint: .top, endPoint: .bottom)))
                .padding(.horizontal, SpacingTokens.xxs1)
                .padding(.top, SpacingTokens.xxs1)
                .padding(.bottom, SpacingTokens.xxs1)
        case .slimBanner:
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                row
                    .padding(.horizontal, SpacingTokens.sm)
                    .frame(height: SpacingTokens.xl - SpacingTokens.xxs)
                    .background(LinearGradient(colors: [palette.deep.opacity(0.94), palette.deep], startPoint: .top, endPoint: .bottom))
                Text("\(server.product) · \(section)")
                    .font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                    .padding(.horizontal, SpacingTokens.sm)
            }
        case .slab:
            row.padding(.horizontal, SpacingTokens.xs2).padding(.top, SpacingTokens.xs).padding(.bottom, SpacingTokens.xxs)
        default:
            row.padding(.horizontal, SpacingTokens.sm).padding(.top, SpacingTokens.sm)
        }
    }

    /// HQ24: the index tab, with the letters in it.
    private var tab: some View {
        Text(server.monogram)
            .font(.system(size: 9.5, weight: .bold, design: .rounded)).tracking(0.5)
            .foregroundStyle(ColorTokens.Text.onFill)
            .frame(width: SpacingTokens.xl, height: SpacingTokens.sm2 + SpacingTokens.micro)
            .background(UnevenRoundedRectangle(bottomLeadingRadius: SpacingTokens.xxs, bottomTrailingRadius: SpacingTokens.xxs, style: .continuous)
                .fill(palette.deep))
    }

    // MARK: Row

    private var row: some View {
        HStack(alignment: spec.lead.isLarge || spec.lines == .nameOnly ? .center : .top, spacing: SpacingTokens.xs2) {
            lead
            lines
            Spacer(minLength: SpacingTokens.xxs)
            trail
            chevron
        }
    }

    @ViewBuilder
    private var chevron: some View {
        if spec.trail == .chevronOnly {
            Image(systemName: "chevron.right").font(SidebarRowConstants.sectionChevronFont).foregroundStyle(ColorTokens.Text.tertiary)
        } else {
            Image(systemName: "chevron.down").font(SidebarRowConstants.sectionChevronFont).foregroundStyle(tertiary)
                .opacity(showsChevron ? 1 : 0)
        }
    }

    // MARK: Lead

    @ViewBuilder
    private var lead: some View {
        switch spec.lead {
        case .none:
            EmptyView()
        case .dot:
            Circle().fill(palette.ink).frame(width: SpacingTokens.xs, height: SpacingTokens.xs).padding(.top, SpacingTokens.xxs1)
        case .ring:
            Circle().stroke(palette.ink, lineWidth: 1.5).frame(width: SpacingTokens.xs2 - 0.5, height: SpacingTokens.xs2 - 0.5).padding(.top, SpacingTokens.xxs)
        case .led:
            ZStack {
                Circle().fill(palette.ink.opacity(0.25)).frame(width: SpacingTokens.sm2, height: SpacingTokens.sm2)
                Circle().fill(palette.ink).frame(width: SpacingTokens.xxs3, height: SpacingTokens.xxs3)
                    .shadow(color: palette.ink.opacity(0.9), radius: SpacingTokens.xxs)
            }
            .padding(.top, SpacingTokens.micro)
        case .engine:
            Image(systemName: "cylinder.split.1x2.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(palette.ink)
                .frame(width: SpacingTokens.md1, height: SpacingTokens.md1)
        case .engineTile:
            RoundedRectangle(cornerRadius: SpacingTokens.xxs2, style: .continuous).fill(palette.deep)
                .frame(width: SpacingTokens.lg - SpacingTokens.micro * 2, height: SpacingTokens.lg - SpacingTokens.micro * 2)
                .overlay { Image(systemName: "cylinder.split.1x2.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(ColorTokens.Text.onFill) }
        case .monogramTile:
            RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous).fill(palette.deep)
                .frame(width: SpacingTokens.xl2, height: SpacingTokens.xl2)
                .overlay { Text(server.monogram).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(ColorTokens.Text.onFill) }
        case .avatarDisc:
            Circle().fill(palette.deep)
                .frame(width: SpacingTokens.xl + SpacingTokens.xxs, height: SpacingTokens.xl + SpacingTokens.xxs)
                .overlay { Text(server.monogram).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(ColorTokens.Text.onFill) }
        }
    }

    // MARK: Lines

    private var name: some View {
        Text(server.name).font(nameFont).foregroundStyle(primary).lineLimit(1)
    }

    private var productSection: some View {
        let text: String
        switch look.line {
        case .today, .caps: text = "\(server.product) · \(section)"
        case .host: text = server.host
        case .none: text = ""
        }
        return Text(text).font(look.line == .host ? TypographyTokens.detailMono : SidebarRowConstants.trailingFont).foregroundStyle(tertiary).lineLimit(1)
    }

    private func caps(_ text: String, tint: Bool) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(0.9)
            .foregroundStyle(tint ? AnyShapeStyle(palette.ink) : (onFill ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.82)) : AnyShapeStyle(ColorTokens.Text.tertiary)))
            .lineLimit(1)
    }

    @ViewBuilder
    private var lines: some View {
        switch spec.lines {
        case .stacked:
            VStack(alignment: .leading, spacing: SpacingTokens.micro) { name; if look.line != .none { productSection } }
        case .eyebrowQuiet:
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) { caps(server.productCaps, tint: false); name }
        case .eyebrowTint:
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                caps(server.productCaps, tint: true)
                if design == .q10 {
                    Text(server.name).font(.system(size: 20, weight: .bold)).foregroundStyle(primary).lineLimit(1)
                } else { name }
            }
        case .eyebrowRule:
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                HStack(spacing: SpacingTokens.xxs2) {
                    caps(server.productCaps, tint: true).fixedSize()
                    Rectangle().fill(LinearGradient(colors: [palette.ink.opacity(0.5), palette.ink.opacity(0)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 0.5)
                }
                name
            }
        case .eyebrowDot:
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                HStack(spacing: SpacingTokens.xxs) {
                    Circle().fill(palette.ink).frame(width: SpacingTokens.xxs, height: SpacingTokens.xxs)
                    caps(server.productCaps, tint: false)
                }
                name
            }
        case .eyebrowSection:
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                caps("\(server.productCaps) · \(section.uppercased())", tint: !onFill)
                name
            }
        case .titleBig:
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(server.name).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(primary).lineLimit(1)
                productSection
            }
        case .titleCountLine:
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(server.name).font(.system(size: 17, weight: .bold)).foregroundStyle(primary).lineLimit(1)
                productSection
            }
        case .titleSerif:
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(server.name).font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(primary).lineLimit(1)
                caps(server.productCaps, tint: false)
            }
        case .crumb:
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                HStack(spacing: SpacingTokens.xxs) {
                    Text(server.name).font(.system(size: 13, weight: .medium)).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(ColorTokens.Text.tertiary)
                    Text(section).font(.system(size: 13, weight: .semibold)).foregroundStyle(primary).lineLimit(1).fixedSize()
                }
                Text(server.product).font(SidebarRowConstants.trailingFont).foregroundStyle(tertiary)
            }
        case .sectionOver:
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(section).font(.system(size: 15, weight: .semibold)).foregroundStyle(primary)
                Text(server.name).font(.system(size: 11, weight: .medium)).foregroundStyle(palette.ink).lineLimit(1)
            }
        case .hostMono:
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                name
                Text("\(server.login)@\(server.host)").font(TypographyTokens.detailMono).foregroundStyle(tertiary).lineLimit(1)
            }
        case .inline:
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs2) {
                name
                Text(server.product).font(SidebarRowConstants.trailingFont).foregroundStyle(tertiary).lineLimit(1)
            }
        case .loginLine:
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                name
                Text("\(server.login) · \(server.latency)").font(SidebarRowConstants.trailingFont).foregroundStyle(tertiary).lineLimit(1)
            }
        case .nameOnly:
            name
        }
    }

    // MARK: Trail

    @ViewBuilder
    private var trail: some View {
        switch spec.trail {
        case .none, .chevronOnly:
            EmptyView()
        case .latency:
            Text(server.latency).font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(tertiary)
        case .count:
            Text("\(server.rows.count)").font(.system(size: 10.5, weight: .semibold)).monospacedDigit().foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.micro)
                .background(ColorTokens.Text.primary.opacity(0.07), in: Capsule())
        case .product:
            Text(server.product).font(SidebarRowConstants.trailingFont).foregroundStyle(tertiary).lineLimit(1)
        }
    }
}

/// Colour behind the header for the composed designs that paint any.
struct LabHQBackdrop: View {
    let design: LabHPDesign
    let palette: LabHPPalette

    var body: some View {
        switch design.spec?.surface {
        case .wash?:
            LinearGradient(colors: [palette.soft(0.2), palette.soft(0)], startPoint: .top, endPoint: .bottom)
        case .pool?:
            RadialGradient(colors: [palette.soft(0.34), palette.soft(0)], center: UnitPoint(x: 0.1, y: 0.3),
                           startRadius: SpacingTokens.none, endRadius: SpacingTokens.xxxl + SpacingTokens.lg)
        default:
            EmptyView()
        }
    }
}

/// HQ25's ribbon: a triangle in the card's top trailing corner.
struct LabHQRibbon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

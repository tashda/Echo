import SwiftUI

/// The top of a server card in one of round 50's forms: name, lines, the right side. Colour that
/// reaches past the header (banner, wash) is painted by the card behind this and the dock.
struct LabHRHeader: View {
    let server: LabSHServer
    let look: LabHRLook
    let section: LabHRSection
    var showsChevron = false
    @Environment(\.colorScheme) private var scheme

    private var form: LabHRForm { look.form }
    private var palette: LabHRPalette { LabHRPalette(tint: look.tint(for: server, scheme: scheme), tone: look.tone) }
    private var onFill: Bool { form.isOnFill }
    private var primary: AnyShapeStyle { onFill ? AnyShapeStyle(ColorTokens.Text.onFill) : AnyShapeStyle(ColorTokens.Text.primary) }
    private var secondary: AnyShapeStyle { onFill ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.85)) : AnyShapeStyle(ColorTokens.Text.tertiary) }

    var body: some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs) {
            lines
            Spacer(minLength: SpacingTokens.xxs)
            rightSide
            chevron
        }
        .padding(.horizontal, form == .inset ? SpacingTokens.xs2 : SpacingTokens.sm)
        .padding(.top, form == .slim ? SpacingTokens.none : (form == .inset ? SpacingTokens.xs : SpacingTokens.sm))
        .padding(.bottom, bottomPadding)
        .frame(height: form == .slim ? SpacingTokens.xl - SpacingTokens.xxs : nil)
    }

    private var bottomPadding: CGFloat {
        switch form {
        case .banner, .bannerTitle: SpacingTokens.sm
        case .inset: SpacingTokens.xs
        default: SpacingTokens.none
        }
    }

    // MARK: Lines

    @ViewBuilder
    private var lines: some View {
        if form == .slim {
            Text(server.name).font(SidebarRowConstants.serverHeaderFont).foregroundStyle(primary).lineLimit(1)
        } else if form.hasLargeName {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                if let eyebrowText { eyebrow(eyebrowText) }
                Text(server.name).font(look.name.font).tracking(look.name.tracking).foregroundStyle(primary).lineLimit(1)
                if look.eyebrow == .none { productLine }
            }
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(server.name).font(SidebarRowConstants.serverHeaderFont).foregroundStyle(primary).lineLimit(1)
                productLine
            }
        }
    }

    private var productLine: some View {
        Text("\(server.product) · \(section.title)").font(SidebarRowConstants.trailingFont).foregroundStyle(secondary).lineLimit(1)
    }

    private var eyebrowText: String? {
        switch look.eyebrow {
        case .engine: server.engineCaps
        case .section: section.title.uppercased()
        case .engineSection: "\(server.engineCaps) · \(section.title.uppercased())"
        case .version: server.product.uppercased()
        case .none: nil
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(look.eyebrowStyle.isCaps ? text : text.capitalized).font(look.eyebrowStyle.font).tracking(look.eyebrowStyle.tracking)
            .foregroundStyle(onFill ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(look.eyebrowStyle.opacity)) : AnyShapeStyle(palette.ink))
            .lineLimit(1)
            .contentTransition(.opacity)
    }

    // MARK: Right side

    @ViewBuilder
    private var rightSide: some View {
        switch look.right {
        case .none:
            EmptyView()
        case .section:
            sectionName
        case .icon:
            sectionDisc
        case .both:
            HStack(spacing: SpacingTokens.xxs2) { sectionDisc; sectionName }
        }
    }

    private var sectionName: some View {
        Text(section.title).font(.system(size: 11, weight: .medium))
            .foregroundStyle(onFill ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.88)) : AnyShapeStyle(ColorTokens.Text.secondary))
            .lineLimit(1)
            .contentTransition(.opacity)
    }

    private var sectionDisc: some View {
        Image(systemName: section.symbol)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(onFill ? AnyShapeStyle(ColorTokens.Text.onFill) : AnyShapeStyle(palette.ink))
            .frame(width: SpacingTokens.lg, height: SpacingTokens.lg)
            .background(onFill ? Color.white.opacity(0.2) : palette.ink.opacity(0.16), in: Circle())
            .contentTransition(.symbolEffect(.replace))
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(SidebarRowConstants.sectionChevronFont)
            .foregroundStyle(onFill ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.85)) : AnyShapeStyle(ColorTokens.Text.tertiary))
            .opacity(showsChevron ? 1 : 0)
    }
}

/// Colour painted behind the header, or behind the header and the dock.
struct LabHRBackdrop: View {
    let form: LabHRForm
    let palette: LabHRPalette
    var edge = LabHREdge.sharp

    var body: some View {
        switch form.surface {
        case .banner:
            LabHRBanner(edge: edge, palette: palette)
        case .wash:
            LinearGradient(colors: [palette.ink.opacity(0.2), palette.ink.opacity(0)], startPoint: .top, endPoint: .bottom)
        case .inset, .none:
            EmptyView()
        }
    }
}


/// The banner's fill, ending against the card in one of round 50's edges.
struct LabHRBanner: View {
    let edge: LabHREdge
    let palette: LabHRPalette

    var body: some View {
        switch edge {
        case .soft:
            palette.banner.mask { LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.62),
                                                         .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom) }
        case .sharp:
            palette.banner
        case .hairline:
            palette.banner.overlay(alignment: .bottom) { Color.white.opacity(0.35).frame(height: 0.5) }
        case .shortFade:
            palette.banner.mask {
                VStack(spacing: SpacingTokens.none) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: SpacingTokens.sm2)
                }
            }
        case .frosted:
            palette.banner.overlay(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial)
                    .frame(height: SpacingTokens.xl + SpacingTokens.xxs)
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
            }
            .mask { LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.8),
                                           .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom) }
        case .lifted:
            palette.banner.shadow(color: .black.opacity(0.28), radius: SpacingTokens.xs, y: SpacingTokens.xxs)
        case .rounded:
            palette.banner.clipShape(UnevenRoundedRectangle(bottomLeadingRadius: SpacingTokens.md1, bottomTrailingRadius: SpacingTokens.md1, style: .continuous))
        case .curve:
            LabHRCurvedBottom(depth: SpacingTokens.xs2).fill(palette.banner)
        case .slanted:
            LabHRSlantedBottom(rise: SpacingTokens.xs2).fill(palette.banner)
        }
    }
}

/// A rectangle whose bottom edge bows down in the middle.
struct LabHRCurvedBottom: Shape {
    let depth: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - depth), control: CGPoint(x: rect.midX, y: rect.maxY + depth))
        path.closeSubpath()
        return path
    }
}

/// A rectangle whose bottom edge rises to the left.
struct LabHRSlantedBottom: Shape {
    let rise: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rise))
        path.closeSubpath()
        return path
    }
}

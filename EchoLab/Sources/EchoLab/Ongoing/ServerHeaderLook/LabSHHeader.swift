import SwiftUI

/// The top of a server card in one of round 30.1's styles: name, second line and, where the style
/// has them, a tile, a status dot or colour behind it. The dock is drawn by the card.
struct LabSHHeader: View {
    let server: LabSHServer
    let look: LabSHLook
    var section = "Databases"
    /// The collapse chevron, shown on hover (round 30.2 decides where it sits).
    var showsChevron = false

    private var tint: Color { look.color(for: server) }
    private var onBanner: Bool { look.style == .banner }

    var body: some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs) {
            leadingTile
            VStack(alignment: .leading, spacing: look.style == .larger ? SpacingTokens.xxxs : SpacingTokens.micro) {
                nameLine
                Text(look.secondLine.text(server, section: section))
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(onBanner ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.85)) : AnyShapeStyle(ColorTokens.Text.tertiary))
                    .lineLimit(1)
            }
            Spacer(minLength: SpacingTokens.xxs)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(SidebarRowConstants.sectionChevronFont)
                    .foregroundStyle(onBanner ? AnyShapeStyle(ColorTokens.Text.onFill) : AnyShapeStyle(ColorTokens.Text.tertiary))
            }
        }
        .padding(.leading, SpacingTokens.sm)
        .padding(.trailing, SpacingTokens.sm)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, onBanner ? SpacingTokens.sm : SpacingTokens.none)
        .background(alignment: .top) { backdrop }
    }

    @ViewBuilder
    private var leadingTile: some View {
        switch look.style {
        case .monogram:
            Text(server.monogram)
                .font(TypographyTokens.caption2.weight(.bold))
                .foregroundStyle(look.isColoured ? tint : ColorTokens.Text.secondary)
                .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg2)
                .background(tint.opacity(look.isColoured ? 0.14 : 0.1), in: .rect(cornerRadius: SpacingTokens.xs, style: .continuous))
        case .engine:
            Image(systemName: server.product.hasPrefix("PostgreSQL") ? "externaldrive.connected.to.line.below" : "cylinder.split.1x2.fill")
                .font(TypographyTokens.prominent.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.onFill)
                .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg2)
                .background(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .top, endPoint: .bottom),
                            in: .rect(cornerRadius: SpacingTokens.xs, style: .continuous))
                .shadow(color: tint.opacity(0.3), radius: 2, y: 1)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var nameLine: some View {
        let name = Text(server.name)
            .font(look.style == .larger ? TypographyTokens.title3.weight(.semibold) : SidebarRowConstants.serverHeaderFont)
            .foregroundStyle(onBanner ? AnyShapeStyle(ColorTokens.Text.onFill) : AnyShapeStyle(ColorTokens.Text.primary))
            .lineLimit(1)
        switch look.style {
        case .status:
            HStack(spacing: SpacingTokens.xxs2) {
                name
                Circle().fill(ColorTokens.Status.success).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
            }
        case .plate:
            name
                .padding(.horizontal, SpacingTokens.xs2)
                .padding(.vertical, SpacingTokens.xxxs)
                .glassEffect(.regular.tint(tint.opacity(look.isColoured ? 0.28 : 0.08)), in: .capsule)
                .padding(.leading, -SpacingTokens.xxs)
        default:
            name
        }
    }

    @ViewBuilder
    private var backdrop: some View {
        switch look.style {
        case .wash:
            LinearGradient(colors: [tint.opacity(look.isColoured ? 0.2 : 0.08), tint.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: SpacingTokens.xxxl + SpacingTokens.xl)
                .allowsHitTesting(false)
        case .banner:
            LinearGradient(colors: [tint.opacity(0.92), tint], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }
}

/// The section dock under the header: a glass capsule as wide as the card, the current icon tinted.
struct LabSHDock: View {
    var current = 0
    var tint: Color = ColorTokens.accent
    private let symbols = ["cylinder", "shield", "square.grid.2x2", "clock", "gearshape"]

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                Image(systemName: symbol)
                    .font(TypographyTokens.prominent.weight(.medium))
                    .foregroundStyle(index == current ? AnyShapeStyle(tint) : AnyShapeStyle(ColorTokens.Sidebar.symbol))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, SpacingTokens.xxs2)
        .frame(height: SpacingTokens.lg + SpacingTokens.xxs)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
    }
}

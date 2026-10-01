import SwiftUI

/// The top of a server card in one of round 30.1's styles: name, second line and, where the style
/// has them, a bar, a plate or a pill. Colour that reaches past the header (washes, banners, the
/// top line) is drawn by the card (`LabSHTopBackdrop`, `LabSHCardEdge`); the dock by the card too.
struct LabSHHeader: View {
    let server: LabSHServer
    let look: LabSHLook
    var section = "Databases"
    /// The collapse chevron, shown on hover (round 30.2 decides where it sits).
    var showsChevron = false
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    private var tint: Color { look.color(for: server) }
    private var onFill: Bool { look.style.isOnFill }

    var body: some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs) {
            textBlock
            Spacer(minLength: SpacingTokens.xxs)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(SidebarRowConstants.sectionChevronFont)
                    .foregroundStyle(onFill ? AnyShapeStyle(ColorTokens.Text.onFill) : AnyShapeStyle(ColorTokens.Text.tertiary))
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, onFill ? SpacingTokens.sm : SpacingTokens.none)
        .background(alignment: .top) {
            switch look.style {
            case .banner:
                LinearGradient(colors: [tint.opacity(0.92), tint], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            case .insetBanner:
                insetBanner
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var textBlock: some View {
        let lines = VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            nameLine
            Text(look.secondLine.text(server, section: section))
                .font(SidebarRowConstants.trailingFont)
                .foregroundStyle(onFill ? AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.85)) : AnyShapeStyle(ColorTokens.Text.tertiary))
                .lineLimit(1)
        }
        switch look.style {
        case .bar:
            // The bar sits in the header's leading padding, so the name stays where today's is.
            lines.overlay(alignment: .leading) {
                Capsule().fill(tint)
                    .frame(width: SpacingTokens.nano)
                    .padding(.vertical, SpacingTokens.micro)
                    .offset(x: -(SpacingTokens.xxs1 + SpacingTokens.nano))
            }
        case .onePlate:
            lines
                .padding(.horizontal, SpacingTokens.xs)
                .padding(.vertical, SpacingTokens.xxs2)
                .glassEffect(.regular.tint(tint.opacity(look.isColoured ? 0.24 : 0.08)),
                             in: .rect(cornerRadius: max(cornerRadius - SpacingTokens.xxs1, SpacingTokens.xxs2), style: .continuous))
                .padding(.leading, -SpacingTokens.xs)
                .padding(.vertical, -SpacingTokens.xxs2)
        default:
            lines
        }
    }

    @ViewBuilder
    private var nameLine: some View {
        let name = Text(server.name)
            .font(SidebarRowConstants.serverHeaderFont)
            .lineLimit(1)
        switch look.style {
        case .plate:
            name.foregroundStyle(ColorTokens.Text.primary)
                .padding(.horizontal, SpacingTokens.xs2)
                .padding(.vertical, SpacingTokens.xxxs)
                .glassEffect(.regular.tint(tint.opacity(look.isColoured ? 0.28 : 0.08)), in: .capsule)
                .padding(.leading, -SpacingTokens.xxs)
        case .pill:
            name.foregroundStyle(look.isColoured ? AnyShapeStyle(tint) : AnyShapeStyle(ColorTokens.Text.primary))
                .padding(.horizontal, SpacingTokens.xs)
                .padding(.vertical, SpacingTokens.xxxs)
                .background(tint.opacity(look.isColoured ? 0.15 : 0.1), in: .capsule)
                .padding(.leading, -SpacingTokens.xxs)
        default:
            name.foregroundStyle(onFill ? AnyShapeStyle(ColorTokens.Text.onFill) : AnyShapeStyle(ColorTokens.Text.primary))
        }
    }

    /// HD15: the banner 5pt in from the card's edges, its corners concentric with the card's.
    private var insetBanner: some View {
        RoundedRectangle(cornerRadius: max(cornerRadius - SpacingTokens.xxs1, SpacingTokens.xxs2), style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.9), tint], startPoint: .top, endPoint: .bottom))
            .padding(.horizontal, SpacingTokens.xxs1)
            .padding(.top, SpacingTokens.xxs1)
            .allowsHitTesting(false)
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

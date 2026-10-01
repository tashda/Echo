import SwiftUI

/// Colour behind the header and the dock together (the washes and HD16). The card
/// puts it behind its top block, so it reaches the card's edges and is clipped by its corners.
struct LabSHTopBackdrop: View {
    let look: LabSHLook
    let tint: Color

    private var strength: Double { look.isColoured ? 1 : 0.4 }

    var body: some View {
        switch look.style {
        case .wash:
            LinearGradient(colors: [tint.opacity(0.2 * strength), tint.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: SpacingTokens.xxxl + SpacingTokens.xl)
                .frame(maxHeight: .infinity, alignment: .top)
        case .cap:
            tint.opacity(0.12 * strength)
                .overlay(alignment: .bottom) {
                    tint.opacity(0.3 * strength).frame(height: LayoutTokens.Workspace.cardEdgeWidth)
                }
        case .glow:
            RadialGradient(colors: [tint.opacity(0.3 * strength), tint.opacity(0)],
                           center: .topLeading, startRadius: SpacingTokens.none, endRadius: SpacingTokens.xxxl * 4)
        case .fadingBanner:
            LinearGradient(stops: [.init(color: tint.opacity(0.95), location: 0),
                                   .init(color: tint.opacity(0.8), location: 0.5),
                                   .init(color: tint.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        default:
            EmptyView()
        }
    }
}

/// The line styles that sit on the card's edge: HD5 follows the top edge round the corners and
/// fades down the sides; HD11 is a short line, clear at both ends, with a faint glow.
struct LabSHCardEdge: View {
    let look: LabSHLook
    let tint: Color
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    var body: some View {
        switch look.style {
        case .edge:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(tint, lineWidth: SpacingTokens.xxxs1)
                .mask(alignment: .top) {
                    LinearGradient(stops: [.init(color: tint, location: 0),
                                           .init(color: tint, location: 0.35),
                                           .init(color: tint.opacity(0), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: cornerRadius + SpacingTokens.md)
                }
        case .fadingLine:
            Capsule()
                .fill(LinearGradient(colors: [tint.opacity(0), tint, tint.opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(height: SpacingTokens.xxxs1)
                .shadow(color: tint.opacity(0.5), radius: SpacingTokens.xxs, y: SpacingTokens.micro)
                .padding(.horizontal, cornerRadius)
                .frame(maxHeight: .infinity, alignment: .top)
        default:
            EmptyView()
        }
    }
}

import SwiftUI

/// The short hairline between the open and the minimized servers in the connected pill
/// (round 55, DV0). It carries no state of its own: the pill draws it only when both groups
/// have a server.
struct ServerRailHairline: View {
    let itemSize: CGFloat

    var body: some View {
        Capsule()
            .fill(ColorTokens.Text.primary.opacity(LayoutTokens.Rail.hairlineOpacity))
            .frame(width: itemSize * LayoutTokens.Rail.hairlineWidthRatio, height: LayoutTokens.Rail.hairlineHeight)
            .padding(.vertical, SpacingTokens.xxs)
            .accessibilityHidden(true)
    }
}

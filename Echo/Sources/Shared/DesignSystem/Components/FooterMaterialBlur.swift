import SwiftUI

/// What lies under a card's floating footer (round 44: BT4, CV6, BH3, TT1): the system's thinnest
/// material with a light tint of the card's colour, faded in from clear at the top to full at the
/// card's edge along an exponential curve, so the rows soften the way the eye sees blur grow
/// rather than meeting a band. It reaches the footer's height plus `EdgeBlur.materialReach`.
struct FooterMaterialBlur: View {
    /// The footer's room and the material's reach above it: the same at the bottom of every card,
    /// with a footer or without (the editor's card with results below it).
    nonisolated static var cardBottomHeight: CGFloat {
        LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift + LayoutTokens.EdgeBlur.materialReach
    }

    var height: CGFloat = cardBottomHeight

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            ColorTokens.Workspace.card.opacity(LayoutTokens.EdgeBlur.materialTintOpacity)
        }
        .mask(LinearGradient(stops: Self.stops().map { .init(color: .black.opacity($0.opacity), location: $0.location) },
                             startPoint: .top, endPoint: .bottom))
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// How much of the material shows at `t`, from 0 at the top of its reach to 1 at the card's edge.
    nonisolated static func amount(at t: CGFloat) -> CGFloat {
        let t = min(max(t, 0), 1)
        let growth = LayoutTokens.EdgeBlur.materialGrowth
        return (exp(growth * t) - 1) / (exp(growth) - 1)
    }

    /// The mask's stops from the top down.
    nonisolated static func stops(samples: Int = 24) -> [(location: CGFloat, opacity: Double)] {
        (0...samples).map { index in
            let t = CGFloat(index) / CGFloat(samples)
            return (t, Double(amount(at: t)))
        }
    }
}

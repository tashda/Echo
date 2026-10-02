import SwiftUI

/// The flight: the card's banner becomes the trail circle. It is an `Animatable` view, so a real
/// spring drives `progress` and every property below is worked out afresh on every frame (no
/// cross-faded snapshots, nothing is squeezed). 0 is the card, 1 is the circle in its place; a
/// spring overshoots 1 a little, which is the bounce.
///
/// The parts, with their share of the move:
///  - the card (its surface and rows) steps aside early, folding into the banner first with FD1;
///  - the banner narrows and rounds into a disc of the server's colour while it travels the path;
///  - from 45% the disc takes the letters; from 84% its fill clears, the letters take the server's
///    colour and the dashed ring draws itself: what is left is the trail item, and the item takes over.

struct LabMVMorph: View, @MainActor Animatable {
    var progress: CGFloat
    let server: LabTIServer
    let flight: LabMVFlight
    let look: LabMVLook
    var cornerRadius: CGFloat = LayoutTokens.Workspace.cardCornerRadius

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var t: Double { Double(progress) }
    private var tint: Color { server.server.color }

    var body: some View {
        ZStack(alignment: .topLeading) {
            card
            disc
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    // MARK: Card

    private var cardOpacity: Double {
        switch look.fold {
        case .direct: 1 - LabMVEase.phase(t, 0.05, 0.5)
        case .rows: 1 - LabMVEase.phase(t, 0.3, 0.62)
        case .banner: 1 - LabMVEase.phase(t, 0, 0.25)
        }
    }

    @ViewBuilder
    private var card: some View {
        let opacity = cardOpacity
        if opacity > 0.002 {
            let height = look.fold == .rows
                ? LabMVEase.lerp(flight.from.height, flight.banner.height, LabMVEase.smooth(LabMVEase.phase(t, 0, 0.45)))
                : flight.from.height
            LabHCCard(server: server.server, look: LabHCLook(), rowLimit: 2, interactive: false)
                .frame(width: flight.from.width, height: flight.from.height, alignment: .top)
                .frame(height: height, alignment: .top)
                .clipped()
                .offset(x: flight.from.minX, y: flight.from.minY)
                .opacity(opacity)
        }
    }

    // MARK: Disc

    /// The banner as it narrows into the circle, and the circle's letters and ring.
    private var disc: some View {
        let size = flight.to.size
        let shape = LabMVEase.smooth(LabMVEase.phase(t, 0.04, 0.78))
        let width = LabMVEase.lerp(flight.banner.width, size.width, shape)
        let height = LabMVEase.lerp(flight.banner.height, size.height, shape)
        let centre = point(on: min(max(t, 0), 1))
        let radius = min(LabMVEase.lerp(cornerRadius, min(width, height) / 2, LabMVEase.smooth(LabMVEase.phase(t, 0.04, 0.7))), min(width, height) / 2)
        let swell = 1 + look.bounce.swell * CGFloat(max(t - 1, 0)) + extraSwell
        let fillOut = LabMVEase.phase(t, 0.84, 1)
        let letters = LabMVEase.phase(t, 0.45, 0.8)
        let ring = look.landing == .disc ? fillOut : LabMVEase.phase(t, 0.86, 1)

        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.92), tint], startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: height)
                .opacity(1 - fillOut)
            Text(server.monogram)
                .font(.system(size: size.width * LayoutTokens.Rail.monogramFontRatio, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.mix(with: tint, by: fillOut))
                .opacity(letters)
            Circle()
                .trim(from: 0, to: max(ring, 0.001))
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .rotationEffect(.degrees(-90))
                .frame(width: size.width - SpacingTokens.micro * 2, height: size.height - SpacingTokens.micro * 2)
                .opacity(ring > 0.001 ? 0.7 : 0)
        }
        .scaleEffect(swell)
        .position(x: centre.x, y: centre.y)
    }

    /// One more swell after the ring closes (LD1).
    private var extraSwell: CGFloat {
        guard look.landing == .ringPop else { return 0 }
        let p = LabMVEase.phase(t, 0.9, 1)
        return 0.12 * CGFloat(sin(p * .pi))
    }

    /// The disc's centre along the path from the banner's centre to the item's. A bowed path leaves
    /// along the card (sideways first) and arrives from the side.
    private func point(on s: Double) -> CGPoint {
        let a = CGPoint(x: flight.banner.midX, y: flight.banner.midY)
        let c = CGPoint(x: flight.to.midX, y: flight.to.midY)
        let bow = look.path.bow
        let control = CGPoint(x: (a.x + c.x) / 2, y: a.y + (c.y - a.y) * (0.5 - bow * 0.5))
        let one = 1 - s
        return CGPoint(x: one * one * a.x + 2 * one * s * control.x + s * s * c.x,
                       y: one * one * a.y + 2 * one * s * control.y + s * s * c.y)
    }
}

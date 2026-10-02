import SwiftUI

/// The title banner's colour (round 53, F5): Echo's banner gradient, the colour at 92% to 100%
/// from top to bottom, ending in the edge the user chose (Settings › Appearance › Server Header).
/// A closed card is all banner and keeps its rounded corners, so it has no edge to draw.
struct ServerTitleBannerFill: View {
    let paint: ServerHeaderPaint
    let shape: UnevenRoundedRectangle
    let isClosed: Bool

    private var gradient: LinearGradient {
        LinearGradient(colors: [paint.fill.opacity(ServerHeaderTokens.bannerTopOpacity), paint.fill],
                       startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        let fill = shape.fill(gradient)
        if isClosed {
            fill
        } else {
            switch paint.look.edge {
            case .sharp:
                fill
            case .hairline:
                fill.overlay(alignment: .bottom) {
                    ColorTokens.Text.onFill.opacity(ServerHeaderTokens.hairlineOpacity).frame(height: ServerHeaderTokens.hairlineWidth)
                }
            case .softFade:
                fill.mask { fade(holding: ServerHeaderTokens.softFadeHold) }
            case .frostedFade:
                fill
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(.ultraThinMaterial)
                            .frame(height: ServerHeaderTokens.frostedBandHeight)
                            .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                    }
                    .mask { fade(holding: ServerHeaderTokens.frostedFadeHold) }
            }
        }
    }

    /// Opaque down to `location`, clear at the bottom.
    private func fade(holding location: Double) -> some View {
        LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: location),
                               .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
    }
}

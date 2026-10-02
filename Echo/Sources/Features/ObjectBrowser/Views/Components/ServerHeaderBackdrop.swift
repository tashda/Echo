import SwiftUI

/// Colour behind a server card's header (round 30.1): HD4's wash, fading from the card's top edge,
/// or HD16's banner, full colour behind the name and fading into the card, or round 53's title
/// banner (F5), the colour in full ending in the edge the user chose. It reaches through the
/// dock while the card is open and covers the whole card while it is closed, cut to the card's
/// corners and kept inside its hairline edge.
struct ServerHeaderBackdrop: View {
    let paint: ServerHeaderPaint
    let height: CGFloat
    let isClosed: Bool
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    var body: some View {
        switch paint.style {
        case .wash:
            shape.fill(LinearGradient(colors: [paint.fill.opacity(paint.color == nil ? 0.08 : 0.2), paint.fill.opacity(0)],
                                      startPoint: .top, endPoint: .bottom))
                .modifier(Placement(height: height))
        case .banner:
            shape.fill(LinearGradient(stops: bannerStops, startPoint: .top, endPoint: .bottom))
                .modifier(Placement(height: height))
        case .titleBanner:
            ServerTitleBannerFill(paint: paint, shape: shape, isClosed: isClosed)
                .modifier(Placement(height: height))
        case .plain, .bar, .plate:
            EmptyView()
        }
    }

    /// Closed, the banner fills the card; open, it fades out through the dock.
    private var bannerStops: [Gradient.Stop] {
        isClosed
            ? [.init(color: paint.fill.opacity(0.95), location: 0), .init(color: paint.fill.opacity(0.85), location: 1)]
            : [.init(color: paint.fill.opacity(0.95), location: 0), .init(color: paint.fill.opacity(0.8), location: 0.5),
               .init(color: paint.fill.opacity(0), location: 1)]
    }

    var shape: UnevenRoundedRectangle {
        let inner = max(cornerRadius - LayoutTokens.Workspace.cardEdgeWidth, 0)
        return UnevenRoundedRectangle(topLeadingRadius: inner, bottomLeadingRadius: isClosed ? inner : 0,
                                      bottomTrailingRadius: isClosed ? inner : 0, topTrailingRadius: inner, style: .continuous)
    }

    struct Placement: ViewModifier {
        let height: CGFloat
        func body(content: Content) -> some View {
            content
                .frame(height: max(height - LayoutTokens.Workspace.cardEdgeWidth * 2, 0))
                .padding(.horizontal, LayoutTokens.Workspace.cardEdgeWidth)
                .padding(.top, LayoutTokens.Workspace.cardEdgeWidth)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

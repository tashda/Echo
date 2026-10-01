import SwiftUI

/// Behind a pinned server name and dock (round 16, Blur rows): nothing while it rests in place;
/// once rows scroll under it, a light wash of the card colour, strongest at the top. The rows
/// blur and fade themselves (`ExplorerRowEdgeBlur`), so together they read like the system's
/// soft scroll edge. It replaces the grey material.
public struct ExplorerPinnedHeaderWash: View {
    let restingMinY: CGFloat
    let scroll: ExplorerTreeScrollState

    public init(restingMinY: CGFloat, scroll: ExplorerTreeScrollState) {
        self.restingMinY = restingMinY
        self.scroll = scroll
    }

    private var isPinned: Bool { scroll.offset > restingMinY + SpacingTokens.micro }

    public var body: some View {
        LinearGradient(stops: [
            .init(color: ColorTokens.Workspace.card.opacity(0.85), location: 0),
            .init(color: ColorTokens.Workspace.card.opacity(0.45), location: 0.55),
            .init(color: ColorTokens.Workspace.card.opacity(0), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .opacity(isPinned ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: isPinned)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A row passing under a pinned header blurs and fades more the higher it goes, so it is a soft
/// haze behind the server's name and a readable blur behind the dock's glass.
public struct ExplorerRowEdgeBlur: ViewModifier {
    /// The pinned header's height; zero for rows with no header above them.
    let headerHeight: CGFloat

    public init(headerHeight: CGFloat) {
        self.headerHeight = headerHeight
    }

    /// The strongest blur, at the card's top edge.
    public static let maxBlur = SpacingTokens.xs2
    /// How far rows fade at the top edge.
    public static let maxFade = 0.92

    public func body(content: Content) -> some View {
        if headerHeight > 0 {
            content.visualEffect { [headerHeight, maxBlur = Self.maxBlur, maxFade = Self.maxFade] effect, proxy in
                let midY = proxy.frame(in: .scrollView).midY
                let progress = min(max((headerHeight - midY) / headerHeight, 0), 1)
                return effect
                    .blur(radius: progress * maxBlur)
                    .opacity(1 - pow(progress, 0.8) * maxFade)
            }
        } else {
            content
        }
    }
}

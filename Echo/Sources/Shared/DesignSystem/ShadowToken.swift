import SwiftUI

public enum ShadowTokens {
    public struct Shadow: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }

    /// Very subtle shadow for rest state cards
    public static let cardRest = Shadow(
        color: Color.black.opacity(0.04),
        radius: 1,
        x: 0,
        y: 0.5
    )

    /// More prominent shadow for selected cards
    public static let cardSelected = Shadow(
        color: Color.black.opacity(0.12),
        radius: 2,
        x: 0,
        y: 0.5
    )

    /// Editor and results cards lifted off the canvas (Design/06-tokens.md).
    public static let workspaceCard = Shadow(
        color: Color.black.opacity(0.12),
        radius: 10,
        x: 0,
        y: 4
    )

    /// A server's card in the tree, at rest: lighter than the editor card so the tree stays calm.
    public static let treeCard = Shadow(
        color: Color.black.opacity(0.04),
        radius: 1.5,
        x: 0,
        y: 0.5
    )

    /// The server card the rail has selected, lifted a little off the canvas.
    public static let treeCardLifted = Shadow(
        color: Color.black.opacity(0.10),
        radius: 6,
        x: 0,
        y: 2
    )

    /// The selection disc in the server rail.
    public static let railSelection = Shadow(
        color: Color.black.opacity(0.16),
        radius: 1.5,
        x: 0,
        y: 0.5
    )

    /// Standard shadow for floating elements
    public static let elevated = Shadow(
        color: Color.black.opacity(0.15),
        radius: 4,
        x: 0,
        y: 2
    )
}

public extension View {
    func shadow(_ token: ShadowTokens.Shadow) -> some View {
        self.shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}

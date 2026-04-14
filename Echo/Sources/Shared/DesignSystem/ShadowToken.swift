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

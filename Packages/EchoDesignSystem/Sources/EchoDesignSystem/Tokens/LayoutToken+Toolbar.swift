import CoreGraphics

extension LayoutTokens {
    /// Toolbar items Echo draws in its own glass (Run, round 24), sized like the system's
    /// icon-only items so they line up with their neighbours.
    public enum Toolbar {
        /// The square an icon-only toolbar item gives its symbol.
        public static let glyph: CGFloat = 28
        /// The glass around it: 4pt at the sides, 2pt above and below, as macOS 26 draws a group.
        public static let capsuleHorizontalPadding: CGFloat = SpacingTokens.xxs
        public static let capsuleVerticalPadding: CGFloat = SpacingTokens.xxxs
    }
}

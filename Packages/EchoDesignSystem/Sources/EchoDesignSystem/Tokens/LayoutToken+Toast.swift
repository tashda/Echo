import CoreGraphics

extension LayoutTokens {
    /// Toasts (plan N2, round 15): one width whether collapsed or expanded, so hovering never
    /// changes their size sideways, and the floating-surface corners.
    public enum Toast {
        public static let width: CGFloat = FloatingSurface.mediumWidth
        public static let cornerRadius: CGFloat = FloatingSurface.cornerRadius
        /// Their inset from the top-right corner of the card they sit in.
        public static let inset: CGFloat = SpacingTokens.xs
        /// How far a toast is flicked to the right before it goes (round 18, D3).
        public static let swipeDismissDistance: CGFloat = 80
        /// How far a dragged toast fades before it is let go.
        public static let swipeFadeLimit: Double = 0.6
    }
}

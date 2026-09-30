import CoreGraphics

extension LayoutTokens {
    /// Toasts (plan N2, round 15): one width whether collapsed or expanded, so hovering never
    /// changes their size sideways, and the floating-surface corners.
    public enum Toast {
        public static let width: CGFloat = FloatingSurface.mediumWidth
        public static let cornerRadius: CGFloat = FloatingSurface.cornerRadius
        /// Their inset from the top-right corner of the card they sit in.
        public static let inset: CGFloat = SpacingTokens.xs
    }
}

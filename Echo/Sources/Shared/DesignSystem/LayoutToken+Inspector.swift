import CoreGraphics

extension LayoutTokens {
    /// The inspector column on the canvas (plan I1–I3, round 10 IN1).
    public enum Inspector {
        public static let minWidth: CGFloat = 260
        public static let idealWidth: CGFloat = 300
        public static let maxWidth: CGFloat = 640
        /// JSON widens the column to at least this, and it returns to the chosen width after.
        public static let jsonWidth: CGFloat = 520
        /// One padding inside every section card, instead of the old doubled gutter.
        public static let cardPadding: CGFloat = SpacingTokens.sm
        public static let rowMinHeight: CGFloat = 24
        /// The gap between a row's label and its value.
        public static let labelValueGap: CGFloat = SpacingTokens.sm
    }
}

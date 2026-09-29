import CoreGraphics

extension LayoutTokens {
    /// The ⌘K palette and the toolbar search card (plan K4). Rows, padding and corners come from
    /// `FloatingSurface`.
    public enum CommandPalette {
        public static let width: CGFloat = 560
        /// The toolbar search card is the floating-surface large width.
        public static let searchCardWidth: CGFloat = FloatingSurface.largeWidth
        public static let listMaxHeight: CGFloat = 360
        /// The palette sits this far below the top of the window's content, like Spotlight.
        public static let topInset: CGFloat = 96
        public static let fieldHeight: CGFloat = 36
        public static let sectionHeaderHeight: CGFloat = 22
    }
}

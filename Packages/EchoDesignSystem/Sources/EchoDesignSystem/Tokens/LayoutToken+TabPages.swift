import AppKit
import SwiftUI

extension LayoutTokens {
    /// Tool pages unfolded inside the active tab (Design/05-components › Tabs, ST2).
    public enum TabPages {
        public static let chipHeight: CGFloat = 20
        public static let chipHorizontalPadding: CGFloat = SpacingTokens.xs
        public static let spacing: CGFloat = SpacingTokens.xxxs
        /// Icon, gaps, close button and padding around the title and chips.
        public static let tabChrome: CGFloat = 76
        /// An unfolded tab never takes more than this share of the strip.
        public static let maxShareOfStrip: CGFloat = 0.62
    }
}

extension ColorTokens.TabStrip {
    public enum Pages {
        public static let track = Color.primary.opacity(0.06)
        public static let selected = Color(nsColor: .textBackgroundColor)
        public static let selectedShadow = Color.black.opacity(0.16)
    }
}

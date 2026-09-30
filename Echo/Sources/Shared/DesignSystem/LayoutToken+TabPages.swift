import AppKit
import SwiftUI

extension LayoutTokens {
    /// Tool pages unfolded inside the active tab (Design/05-components › Tabs, ST2).
    enum TabPages {
        static let chipHeight: CGFloat = 20
        static let chipHorizontalPadding: CGFloat = SpacingTokens.xs
        static let spacing: CGFloat = SpacingTokens.xxxs
        /// Icon, gaps, close button and padding around the title and chips.
        static let tabChrome: CGFloat = 76
        /// An unfolded tab never takes more than this share of the strip.
        static let maxShareOfStrip: CGFloat = 0.62
    }
}

extension ColorTokens.TabStrip {
    enum Pages {
        static let track = Color.primary.opacity(0.06)
        static let selected = Color(nsColor: .textBackgroundColor)
        static let selectedShadow = Color.black.opacity(0.16)
    }
}

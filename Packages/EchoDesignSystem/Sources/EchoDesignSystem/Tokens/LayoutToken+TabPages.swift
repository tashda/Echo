import AppKit
import SwiftUI

extension LayoutTokens {
    /// Tool pages in the active tab (Design/05-components › Tabs, ST2 refined in round 36.1):
    /// the title, a short hairline, then the pages on the tab itself, the shown one on a soft pill.
    public enum TabPages {
        public static let chipHeight: CGFloat = 20
        public static let chipHorizontalPadding: CGFloat = SpacingTokens.xs2
        public static let spacing: CGFloat = SpacingTokens.xxxs
        /// The hairline between the title and the pages.
        public static let dividerHeight: CGFloat = SpacingTokens.sm
        public static let dividerWidth: CGFloat = SpacingTokens.micro
        /// Space either side of the hairline, besides the title's own gap.
        public static let dividerPadding: CGFloat = SpacingTokens.xxxs
        /// Icon, gaps, the hairline, close button and padding around the title and pages.
        public static let tabChrome: CGFloat = 76 + dividerWidth + dividerPadding * 2 + SpacingTokens.xxs2
        /// A tab with pages never takes more than this share of the strip.
        public static let maxShareOfStrip: CGFloat = 0.62
    }
}

extension ColorTokens.TabStrip {
    public enum Pages {
        /// The shown page's pill, on the white active tab (round 36.1, RT2).
        public static let selected = Color.primary.opacity(0.06)
        /// Before round 36.1 the pages sat on a grey track, the shown one white and raised. Kept
        /// for Echo Labs' record of that look only.
        public static let formerTrack = Color.primary.opacity(0.06)
        public static let formerRaised = Color(nsColor: .textBackgroundColor)
        public static let formerRaisedShadow = Color.black.opacity(0.16)
    }
}

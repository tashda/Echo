import SwiftUI

extension LayoutTokens {
    /// The EchoSense popup (Design/05-components › EchoSense).
    public enum EchoSense {
        public static let rowHeight: CGFloat = 24
        public static let visibleRows = 8
        public static let padding: CGFloat = SpacingTokens.xxs
        /// The popup's corner follows Card Corners but stops here, so rows stay concentric.
        public static let maxCornerRadius: CGFloat = 14
        public static let minCornerRadius: CGFloat = SpacingTokens.xs
        public static let minWidth: CGFloat = 300
        public static let maxWidth: CGFloat = 480
        public static let badgeSize: CGFloat = 16
        public static let badgeCornerRadius: CGFloat = SpacingTokens.xxs
        public static let rowSpacing: CGFloat = SpacingTokens.xs
        public static let rowHorizontalPadding: CGFloat = SpacingTokens.xs
        public static let chipHorizontalPadding: CGFloat = SpacingTokens.xxs1
        public static let footerPadding: CGFloat = SpacingTokens.xs
        public static let footerLineSpacing: CGFloat = SpacingTokens.xxxs
        public static let keyHintSpacing: CGFloat = SpacingTokens.sm
        /// Space between the caret's line and the popup.
        public static let caretGap: CGFloat = SpacingTokens.xxs

        public static func cornerRadius(cardCornerRadius: CGFloat) -> CGFloat {
            min(max(cardCornerRadius, minCornerRadius), maxCornerRadius)
        }

        public static func rowCornerRadius(cardCornerRadius: CGFloat) -> CGFloat {
            max(cornerRadius(cardCornerRadius: cardCornerRadius) - padding, SpacingTokens.xxs)
        }
    }
}

extension ColorTokens {
    /// The EchoSense popup: card material, a tint while typing, the accent once choosing.
    public enum EchoSense {
        public static let background = Color(nsColor: .textBackgroundColor)
        public static let edge = Color(nsColor: .separatorColor)
        public static let typingSelection = Color.accentColor.opacity(0.16)
        public static let choosingSelection = Color.accentColor
        public static let choosingText = Color(nsColor: .alternateSelectedControlTextColor)
        public static let match = Color.accentColor
        public static let chip = Color.primary.opacity(0.07)
        public static let footer = Color.primary.opacity(0.035)
        public static let badgeFillOpacity = 0.16
    }
}

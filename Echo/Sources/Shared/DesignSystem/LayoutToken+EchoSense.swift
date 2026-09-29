import SwiftUI

extension LayoutTokens {
    /// The EchoSense popup (Design/05-components › EchoSense).
    enum EchoSense {
        static let rowHeight: CGFloat = 24
        static let visibleRows = 8
        static let padding: CGFloat = SpacingTokens.xxs
        /// The popup's corner follows Card Corners but stops here, so rows stay concentric.
        static let maxCornerRadius: CGFloat = 14
        static let minCornerRadius: CGFloat = SpacingTokens.xs
        static let minWidth: CGFloat = 300
        static let maxWidth: CGFloat = 480
        static let badgeSize: CGFloat = 16
        static let badgeCornerRadius: CGFloat = SpacingTokens.xxs
        static let rowSpacing: CGFloat = SpacingTokens.xs
        static let rowHorizontalPadding: CGFloat = SpacingTokens.xs
        static let chipHorizontalPadding: CGFloat = SpacingTokens.xxs1
        static let footerPadding: CGFloat = SpacingTokens.xs
        static let footerLineSpacing: CGFloat = SpacingTokens.xxxs
        static let keyHintSpacing: CGFloat = SpacingTokens.sm
        /// Space between the caret's line and the popup.
        static let caretGap: CGFloat = SpacingTokens.xxs

        static func cornerRadius(cardCornerRadius: CGFloat) -> CGFloat {
            min(max(cardCornerRadius, minCornerRadius), maxCornerRadius)
        }

        static func rowCornerRadius(cardCornerRadius: CGFloat) -> CGFloat {
            max(cornerRadius(cardCornerRadius: cardCornerRadius) - padding, SpacingTokens.xxs)
        }
    }
}

extension ColorTokens {
    /// The EchoSense popup: card material, a tint while typing, the accent once choosing.
    enum EchoSense {
        static let background = Color(nsColor: .textBackgroundColor)
        static let edge = Color(nsColor: .separatorColor)
        static let typingSelection = Color.accentColor.opacity(0.16)
        static let choosingSelection = Color.accentColor
        static let choosingText = Color(nsColor: .alternateSelectedControlTextColor)
        static let match = Color.accentColor
        static let chip = Color.primary.opacity(0.07)
        static let footer = Color.primary.opacity(0.035)
        static let badgeFillOpacity = 0.16
    }
}

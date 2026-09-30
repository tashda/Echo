import SwiftUI

extension LayoutTokens {
    /// Sizes for the round 14 Design Lab pages (tab bar and tool pages, section dock,
    /// connections, EchoSense selection). Proposals only; nothing in Echo reads them yet.
    enum DesignLabRound14 {
        // Window mock
        static let windowWidth: CGFloat = 940
        static let treeWidth: CGFloat = 220
        static let contentHeight: CGFloat = 190
        static let gutter: CGFloat = SpacingTokens.xxs2

        // Tab bar (today's strip metrics: 32pt footprint, 28pt plate)
        static let barHeight: CGFloat = 32
        static let plateHeight: CGFloat = 28
        static let tabHeight: CGFloat = 24
        static let plateCornerRadius: CGFloat = SpacingTokens.xs2
        static let tabCornerRadius: CGFloat = SpacingTokens.xxs3
        static let plateInset: CGFloat = SpacingTokens.xxs
        static let tabIconWidth: CGFloat = SpacingTokens.sm2
        static let addButtonWidth: CGFloat = SpacingTokens.lg2
        static let dividerHeight: CGFloat = SpacingTokens.sm
        static let dividerWidth: CGFloat = 1
        static let liftEdgeWidth: CGFloat = 0.5
        static let innerShadowRadius: CGFloat = 1.5
        static let innerShadowY: CGFloat = 1
        static let liftShadowRadius: CGFloat = 0.5
        static let liftShadowY: CGFloat = 0.5
        static let unfoldedTabShare: CGFloat = 3.2

        // Tool pages
        static let drawerHeight: CGFloat = 30
        static let pageChipHeight: CGFloat = 22
        static let pageChipCornerRadius: CGFloat = 11
        static let notchWidth: CGFloat = SpacingTokens.sm
        static let notchHeight: CGFloat = SpacingTokens.xxs2
        static let pageStagger: Double = 0.03
        static let secondBarHeight: CGFloat = 28
        static let groupChipCornerRadius: CGFloat = SpacingTokens.xxs3

        // Section dock
        static let dockCardWidth: CGFloat = 300
        static let dockCardHeight: CGFloat = 460
        static let dockButtonSize: CGFloat = 30
        static let dockButtonCornerRadius: CGFloat = SpacingTokens.xs

        // Connections
        static let manageWidth: CGFloat = 900
        static let manageHeight: CGFloat = 560
        static let manageSidebarWidth: CGFloat = 170
        static let manageListWidth: CGFloat = 230

        // EchoSense
        static let senseEditorWidth: CGFloat = 640
        static let senseEditorHeight: CGFloat = 330
        static let sensePopupWidth: CGFloat = 330
        static let senseRowHeight: CGFloat = 24
        static let sensePopupPadding: CGFloat = SpacingTokens.xxs
        static let sensePopupMaxCorner: CGFloat = 14
        static let senseBadgeSize: CGFloat = 16
        static let senseBadgeCornerRadius: CGFloat = SpacingTokens.xxs
    }
}

import SwiftUI

public enum LayoutTokens {
    public enum ServerRail {
        /// Width of the rail column along the open sidebar's leading edge.
        public static let width: CGFloat = 46

        /// Diameter of every rail item: servers, the + button and the glass lens.
        public static let itemSize: CGFloat = 32

        /// How far the status ring sits outside an item's circle.
        public static let ringOutset: CGFloat = 3

        /// Vertical gap between rail items.
        public static let itemSpacing: CGFloat = SpacingTokens.xs

        /// Height of the tool buttons at the bottom of the rail.
        public static let toolHeight: CGFloat = 28

        /// Inset between the floating rail's glass capsule and its items.
        public static let floatingPadding: CGFloat = SpacingTokens.xxs

        /// Pulls the Explorer toward the rail so the two read as one column.
        public static let contentLeadingOverlap: CGFloat = SpacingTokens.xxs
    }

    public enum QueryGlance {
        public static let width: CGFloat = 300
        public static let maxHeight: CGFloat = 440
        public static let cornerRadius: CGFloat = 22
        public static let groupCornerRadius: CGFloat = 14
        public static let rowHeight: CGFloat = 26
        /// Gap between the rail and the panel.
        public static let railGap: CGFloat = SpacingTokens.xxs
    }

    public enum TabNavigation {
        /// Apple recommends a menu or another navigation pattern beyond six tabs.
        public static let maximumVisibleTabCount = 6

        /// A stable width for a prominent two-item tab picker with descriptive labels.
        public static let compactPickerWidth: CGFloat = 360

        /// A stable width for a prominent five-item tab picker. This prevents the
        /// selected tab's native highlight from changing the control's alignment.
        public static let widePickerWidth: CGFloat = 560

        /// Preserves the same per-item proportions as the five-item picker when a
        /// page-level navigation control contains six destinations.
        public static let expandedPickerWidth: CGFloat = 672

        /// Preserves Maintenance's established 112pt segment proportion.
        public static let itemWidth = widePickerWidth / 5

        public static func pickerWidth(itemCount: Int) -> CGFloat {
            max(compactPickerWidth, CGFloat(itemCount) * itemWidth)
        }
    }

    public enum SplitView {
        /// Keeps both sides of an adjustable tab-content split usable.
        public static let minimumPaneHeight: CGFloat = 150
    }

    public enum Icon {
        /// Default square canvas for icon assets embedded inline with 13pt text.
        public static let standardCanvas: CGFloat = SpacingTokens.md
        /// Visual glyph size inside the standard canvas.
        public static let standardGlyph: CGFloat = SpacingTokens.sm

        /// Landing-page recent connection icon canvas with no background tile.
        public static let landingRecentCanvas: CGFloat = SpacingTokens.md2
        /// Landing-page recent connection glyph size tuned for card rows.
        public static let landingRecentGlyph: CGFloat = SpacingTokens.md2

        /// Tight 16pt menu canvas matching AppKit/SwiftUI menu row expectations.
        public static let menuCanvas: CGFloat = SpacingTokens.md
        /// Menu glyph size aligned with the Manage Connections / form-control reference.
        public static let menuGlyph: CGFloat = SpacingTokens.md

        /// Form control icon canvas for pop-up buttons and picker labels.
        public static let formControlCanvas: CGFloat = SpacingTokens.md
        /// Form control glyph size tuned to match Manage Connections type icons.
        public static let formControlGlyph: CGFloat = SpacingTokens.md

        /// Sidebar server icon canvas width.
        public static let sidebarCanvasWidth: CGFloat = SpacingTokens.md1
        /// Sidebar server icon canvas height.
        public static let sidebarCanvasHeight: CGFloat = SpacingTokens.md
        /// Sidebar glyph size inside the Tahoe-style sidebar row.
        public static let sidebarGlyph: CGFloat = SpacingTokens.sm
    }

    public enum Form {
        /// 32pt — Standard minimum height for a settings or property row (compact Tahoe style)
        public static let rowMinHeight: CGFloat = 32
        
        /// Standard width for a control (Pop-up button, Toggle, etc.)
        public static let controlWidth: CGFloat = 120
        /// Maximum width for more complex controls
        public static let controlMaxWidth: CGFloat = 160
        
        /// Standard horizontal padding for internal row content
        public static let horizontalPadding: CGFloat = 12
        /// Standard vertical spacing between grouped sections
        public static let sectionSpacing: CGFloat = 20
        /// Standard vertical spacing between row label and its subtitle
        public static let labelSubtitleSpacing: CGFloat = 2

        /// Width of the info icon button and its alignment placeholder
        public static let infoButtonWidth: CGFloat = SpacingTokens.md1 // 18pt
        /// Standard width for info popovers in settings
        public static let infoPopoverWidth: CGFloat = 280
    }
}

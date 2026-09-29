import SwiftUI

public enum LayoutTokens {
    /// The canvas-and-cards window (Design/02-layout.md, 06-tokens.md).
    public enum Workspace {
        /// Corner radius of the editor and results cards.
        public static let cardCornerRadius: CGFloat = 12
        /// Opacity of the 0.5pt separator edge around cards.
        public static let cardEdgeOpacity: Double = 0.35
        /// Width of the separator edge around cards.
        public static let cardEdgeWidth: CGFloat = 0.5
        /// Default tree width, and its limits when dragging its edge.
        public static let treeIdealWidth: CGFloat = 260
        public static let treeMinWidth: CGFloat = 200
        public static let treeMaxWidth: CGFloat = 480
        /// Width of the invisible drag area on the tree's trailing edge.
        public static let treeResizeHandleWidth: CGFloat = 8
    }

    /// The two-pill server rail of the canvas-and-cards window. Item size comes from the
    /// `railItemSize` setting (`RailItemSize.points`).
    public enum Rail {
        /// Gap between server items inside the pill.
        public static let itemSpacing: CGFloat = SpacingTokens.xxs
        /// Inset between the pill's edge and its items.
        public static let pillPadding: CGFloat = SpacingTokens.xxs
        /// Smallest gap between the server pill and the tool pill.
        public static let minimumPillGap: CGFloat = SpacingTokens.sm
        /// Height of a tool button in the tool pill.
        public static let toolHeight: CGFloat = 30
        /// Opacity of a server whose connection was lost, and of a connecting server with
        /// Reduce Motion on.
        public static let lostOpacity: Double = 0.4
        /// Inset between the selection disc and its item, so the disc never echoes the pill's edge.
        public static let selectionInset: CGFloat = 3
        /// Monogram point size as a share of the item size (12.5pt at the default 34pt).
        public static let monogramFontRatio: CGFloat = 0.37
        /// Point size of the tool symbols.
        public static let toolSymbolSize: CGFloat = 13
        /// Gap between tool buttons inside the tool pill.
        public static let toolSpacing: CGFloat = SpacingTokens.xxxs

        /// Rail width for an item size: the item plus the pill padding on both sides.
        public static func width(itemSize: CGFloat) -> CGFloat { itemSize + pillPadding * 2 }
    }

    /// The welcome on the canvas while no tab is open.
    public enum Welcome {
        public static let width: CGFloat = FloatingSurface.largeWidth
        public static let iconSize: CGFloat = SpacingTokens.xxxl
        /// Inset around the recent connections inside their card.
        public static let listPadding: CGFloat = SpacingTokens.xxs
        public static let monogramSize: CGFloat = 12
        public static let monogramWidth: CGFloat = SpacingTokens.lg
    }

    /// Echo's own floating glass cards: peek, pickers, notification history, search results.
    public enum FloatingSurface {
        public static let smallWidth: CGFloat = 260
        public static let mediumWidth: CGFloat = 320
        public static let largeWidth: CGFloat = 420
        public static let padding: CGFloat = SpacingTokens.sm
        public static let cornerRadius: CGFloat = 18
        public static let rowHeight: CGFloat = 28
        public static let rowCornerRadius: CGFloat = 10
    }

    public enum PinnedPath {
        /// Height of the pinned "server › database" line above the Explorer.
        public static let height: CGFloat = 28
        /// How far the blur keeps fading below the line.
        public static let fadeExtent: CGFloat = 14
        /// How far the blur fades in at each side.
        public static let sideFade: CGFloat = SpacingTokens.xs
        /// Canvas colour laid over the blur, so it matches the canvas instead of the material.
        public static let canvasTintOpacity: Double = 0.7
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

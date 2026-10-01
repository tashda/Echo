import SwiftUI

public enum LayoutTokens {
    /// Dimensions for the single-line tab proposals in the debug Design Lab.
    public enum TabProposals {
        public static let previewWidth: CGFloat = 920
        public static let treeWidth: CGFloat = 220
        public static let editorHeight: CGFloat = 150
        public static let tabHeight: CGFloat = 30
        public static let barHeight: CGFloat = 38
        public static let tabCornerRadius: CGFloat = SpacingTokens.xs
        public static let activeRuleHeight: CGFloat = SpacingTokens.xxxs
        public static let tabIconWidth: CGFloat = SpacingTokens.md
        public static let addButtonWidth: CGFloat = SpacingTokens.xl
    }

    /// The canvas-and-cards window (Design/02-layout.md, 06-tokens.md).
    public enum Workspace {
        /// Default corner radius of every card, matching the macOS 27 window corner. The Card
        /// Corners setting overrides it; views read `@Environment(\.workspaceCardCornerRadius)`.
        public static let cardCornerRadius: CGFloat = 16
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
        /// The editor card's height while the results are maximised: about one line of SQL.
        public static let collapsedEditorHeight: CGFloat = 40
        /// The grab capsule that appears on the gap between the editor and results cards.
        public static let gapHandleWidth: CGFloat = 36
        public static let gapHandleHeight: CGFloat = 4
        /// Extra room above and below the gap that still grabs it, since the gap itself is thin.
        public static let gapHitSlop: CGFloat = SpacingTokens.xxs
        /// Room below a server's last row inside its card in the tree.
        public static let treeCardBottomPadding: CGFloat = SpacingTokens.xxs
        /// Corner of a tree row's hover and selection fill (tree style S1).
        public static let treeRowCornerRadius: CGFloat = SpacingTokens.xs
        /// Extra room above a server-level section heading (Databases, Security…).
        public static let treeSectionTopPadding: CGFloat = SpacingTokens.xxs

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

    /// The footer at the bottom of a tab's card (FT1a).
    public enum Footer {
        public static let height: CGFloat = 34
        public static let chipHeight: CGFloat = 24
        public static let chipHorizontalPadding: CGFloat = SpacingTokens.xs2
        public static let pillPadding: CGFloat = SpacingTokens.xxxs
        public static let segmentWidth: CGFloat = 28
        /// How far the footer sits above its card's bottom edge beyond its own padding (round 9, FP1).
        public static let bottomLift: CGFloat = SpacingTokens.xxs
        /// Tallest the database switcher's list grows before it scrolls.
        public static let switcherListMaxHeight: CGFloat = 280
        /// From a card's bottom edge to the bottom of the footer's pills: the lift plus the
        /// footer's own room around its chips (9pt).
        public static var pillInset: CGFloat { bottomLift + (height - chipHeight) / 2 }
        /// Where a horizontal scroll bar's thumb ends above the card's bottom edge: on the footer's
        /// top edge, kept as far above the pills as the pills sit above the edge (round 27, E).
        public static var scrollBarBottom: CGFloat { pillInset * 2 + chipHeight }
        /// How far an overlay scroll bar's thumb sits inside its frame's bottom edge (measured on
        /// macOS 26, 2026-10-01), so the thumb, not the frame, keeps the pills' spacing.
        public static let overlayThumbInset: CGFloat = 3
        /// The scroller inset that puts the thumb at `scrollBarBottom` over a footer `footerHeight`
        /// tall. AppKit adds the scroller inset to the content inset (the footer's room), which
        /// Echo once set to the footer's height twice; the bar floated a footer above the footer.
        public static func scrollerInset(overFooter footerHeight: CGFloat) -> CGFloat {
            footerHeight > 0 ? scrollBarBottom - overlayThumbInset - footerHeight : 0
        }
    }

    /// The soft blur of content passing under floating controls, such as the footer
    /// (`BackdropEdgeBlur`, round 9 FB1).
    public enum EdgeBlur {
        /// How far the blur keeps fading beyond the control it sits under.
        public static let fade: CGFloat = SpacingTokens.md
        /// Blur radii from where it meets the sharp content to the edge.
        public static let radii: [CGFloat] = [1, 3, 6, 10]
        /// Share of the band over which each blur step fades into the next.
        public static let step: CGFloat = 0.3
        /// Card-coloured tint over the blur, so the control on it stays readable.
        public static let tintOpacity: Double = 0.35
        /// How wide the rows fade at a side where more columns wait (round 27, X1).
        public static let sideFadeWidth: CGFloat = SpacingTokens.xl
    }

    /// The SQL editor's line-number gutter (Design/05-components.md › Editor card).
    public enum EditorGutter {
        /// The gutter always fits at least this many digits, so it doesn't jump at line 10.
        public static let minimumDigits = 2
        public static let markerSize: CGFloat = 5
        public static let markerLeading: CGFloat = SpacingTokens.xxs
        public static let markerSpacing: CGFloat = SpacingTokens.xxxs
        /// From the numbers to the gutter's edge; with the text view's 9pt inset the code starts
        /// 16pt after the numbers (round 28.1).
        public static let numberTrailing: CGFloat = SpacingTokens.xxs3
        /// QE4's rounded band on the current line, removed in round 28.3 (CL1); Echo Labs still
        /// draws it for Echo before round 28.
        public static let currentLineInset: CGFloat = SpacingTokens.xxs2
        public static let currentLineCornerRadius: CGFloat = SpacingTokens.xxs2
        public static let edgeWidth: CGFloat = 0.5
        /// Tinted lane (GT2): inset from the card's edges, rounded, no edge line.
        public static let laneInset: CGFloat = SpacingTokens.xxs1
        public static let laneCornerRadius: CGFloat = SpacingTokens.xs
        /// QE1: the Run arrow on the statement at the caret.
        public static let runArrowSize: CGFloat = 8
        /// QE1: the band behind the statement at the caret, replaced by the bracket in round 28.4
        /// (Echo Labs still draws it for Echo before round 28).
        public static let statementBandOpacity: CGFloat = 0.06
        /// Round 28.4 (B1): the bracket beside the statement's line numbers.
        public static let statementBracketGap: CGFloat = SpacingTokens.xxs
        public static let statementBracketWidth: CGFloat = SpacingTokens.xxxs
        public static let statementBracketInset: CGFloat = SpacingTokens.xxxs
        public static let statementBracketOpacity: CGFloat = 0.7
        /// QE2: the gap between a statement's last character and its run note.
        public static let runNoteGap: CGFloat = SpacingTokens.md2
    }

    /// Placeholder rows while a list loads (`ShimmerPlaceholderRows`).
    public enum Shimmer {
        /// Placeholder rows standing in for one loading row in the Explorer.
        public static let explorerRowCount = 3
        public static let iconSize: CGFloat = 13
        public static let iconCornerRadius: CGFloat = 3
        public static let barHeight: CGFloat = 8
        /// Width of the moving highlight, as a share of the rows' width.
        public static let sweepWidthFraction: CGFloat = 0.4
        public static let sweepDuration: Double = 1.4
    }

    /// The welcome on the canvas while no tab is open.
    public enum Welcome {
        public static let width: CGFloat = FloatingSurface.largeWidth
        public static let iconSize: CGFloat = SpacingTokens.xxxl
        public static let titleSize: CGFloat = 26
        /// Inset around the recent connections inside their card.
        public static let listPadding: CGFloat = SpacingTokens.xxs
        public static let monogramSize: CGFloat = 12
        public static let monogramWidth: CGFloat = SpacingTokens.lg
    }

    /// The server page on the canvas while a server is active and no tab is open.
    public enum ServerPage {
        public static let width: CGFloat = 600
        public static let nameSize: CGFloat = 26
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

// Copied from Echo/Sources/Features/ObjectBrowser/Views/Components/ExplorerRowModels.swift (SidebarRowConstants). Original stays in Echo until the Design Lab is removed.
import SwiftUI

/// Shared metrics for the S4 Quiet tree rows.
enum SidebarRowConstants {
    /// A folder's icon becomes this chevron while the pointer is over its row.
    static let chevronFont = TypographyTokens.detail.weight(.semibold)
    static let sectionChevronFont = TypographyTokens.compact.weight(.bold)
    /// Used by server and section headings, which retain their trailing chevrons.
    static let chevronWidth: CGFloat = SpacingTokens.sm // 12pt
    /// Icon font — Regular weight, renders within 18×16pt frame.
    static let iconFont = Font.system(size: 14, weight: .regular)
    /// Icon frame width — 18pt (Figma: W 18).
    static let iconFrameWidth: CGFloat = SpacingTokens.md1 // 18pt
    /// Icon frame height — 16pt (Figma: H 16).
    static let iconFrameHeight: CGFloat = SpacingTokens.md // 16pt
    /// Legacy square frame — use iconFrameWidth/iconFrameHeight instead.
    static let iconFrame: CGFloat = SpacingTokens.md1 // 18pt (width)
    /// Space between the single icon slot and label.
    static let iconTextSpacing: CGFloat = SpacingTokens.xs // 8pt
    /// Primary label font — 11pt Regular (matches Finder sidebar default density).
    static let labelFont = Font.system(size: 11, weight: .regular)
    /// Font for trailing metadata (counts, types, badges) — matches Finder "Detail".
    /// Monospaced digits so right-aligned counts (40 / 51 / 2) align cleanly.
    static let trailingFont = TypographyTokens.detail.monospacedDigit()
    /// Section header font (Finder-style: 11pt, bold).
    static let sectionHeaderFont = TypographyTokens.detail.weight(.bold)
    /// The server's name at the top of its card: bold 13pt.
    static let serverHeaderFont = TypographyTokens.standard.weight(.bold)
    /// Server-level section headings (Databases, Security…): 11pt semibold.
    static let sectionHeadingFont = TypographyTokens.detail.weight(.semibold)
    /// Per-level indentation step — 16pt per tree level.
    static let indentStep: CGFloat = SpacingTokens.md
    /// Leading padding inside row content highlight area — 6pt.
    static let rowLeadingPadding: CGFloat = SpacingTokens.xxs2 // 6pt
    /// Trailing padding inside rows — 8pt (Figma: trailing 8).
    static let rowTrailingPadding: CGFloat = SpacingTokens.xs // 8pt
    /// Vertical padding for rows — 4pt top/bottom (Figma: top 4, bottom 4).
    static let rowVerticalPadding: CGFloat = SpacingTokens.xxs
    /// Outer horizontal padding — selection pill inset from sidebar edges.
    static let rowOuterHorizontalPadding: CGFloat = SpacingTokens.xxs2 // 6pt
    /// Hover/selection highlight corner radius.
    static let hoverCornerRadius: CGFloat = LayoutTokens.Workspace.treeRowCornerRadius
    /// Spacing between major sidebar sections.
    static let sectionGroupSpacing: CGFloat = SpacingTokens.xxs

    // MARK: - Legacy aliases (use during migration, remove after)

    /// Legacy alias — use `rowLeadingPadding` in new code.
    static let rowHorizontalPadding: CGFloat = 0
}

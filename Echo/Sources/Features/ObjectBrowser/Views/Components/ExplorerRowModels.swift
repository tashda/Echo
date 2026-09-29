import SwiftUI

struct HoveredExplorerRowIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

struct SidebarDensityKey: EnvironmentKey {
    static let defaultValue: SidebarDensity = .medium
}

struct SetHoveredExplorerRowIDKey: EnvironmentKey {
    static let defaultValue: @Sendable (String?) -> Void = { _ in }
}

extension EnvironmentValues {
    var hoveredExplorerRowID: String? {
        get { self[HoveredExplorerRowIDKey.self] }
        set { self[HoveredExplorerRowIDKey.self] = newValue }
    }

    var setHoveredExplorerRowID: @Sendable (String?) -> Void {
        get { self[SetHoveredExplorerRowIDKey.self] }
        set { self[SetHoveredExplorerRowIDKey.self] = newValue }
    }

    var sidebarDensity: SidebarDensity {
        get { self[SidebarDensityKey.self] }
        set { self[SidebarDensityKey.self] = newValue }
    }
}

enum ExplorerColumnMetrics {
    /// Hierarchy depth for column rows (nested under objects at depth 3).
    static let depth: Int = 4
    static let highlightExtension: CGFloat = SpacingTokens.xs2
    static let iconSize: CGFloat = SpacingTokens.md
    static let spacing: CGFloat = SpacingTokens.xs
}

/// Shared constants for sidebar row consistency (macOS 26 Tahoe Finder sidebar aesthetic).
///
/// Measured from macOS 26 Tahoe Finder sidebar (Medium size):
/// - 13pt text, 20pt icon frame, ~28pt row height
/// - 18pt indentation per tree level
/// - Fixed 16pt disclosure column (always present for alignment)
/// - Selection pill inset 8pt from sidebar edges, 10pt corner radius
/// - All icons monochrome secondary gray, Medium visual weight
enum SidebarRowConstants {
    /// Chevron font: 9pt bold in the quaternary grey, lighter than the icon beside it (tree style S1).
    static let chevronFont = TypographyTokens.compact.weight(.bold)
    /// Fixed-width disclosure column — always present for icon alignment.
    static let chevronWidth: CGFloat = SpacingTokens.sm // 12pt
    /// Icon font — Regular weight, renders within 18×16pt frame.
    static let iconFont = Font.system(size: 14, weight: .regular)
    /// Icon frame width — 18pt (Figma: W 18).
    static let iconFrameWidth: CGFloat = SpacingTokens.md1 // 18pt
    /// Icon frame height — 16pt (Figma: H 16).
    static let iconFrameHeight: CGFloat = SpacingTokens.md // 16pt
    /// Legacy square frame — use iconFrameWidth/iconFrameHeight instead.
    static let iconFrame: CGFloat = SpacingTokens.md1 // 18pt (width)
    /// Spacing between chevron, icon and label (tree style S1).
    static let iconTextSpacing: CGFloat = SpacingTokens.xxs3 // 7pt
    /// Primary label font — 11pt Regular (matches Finder sidebar default density).
    static let labelFont = Font.system(size: 11, weight: .regular)
    /// Font for trailing metadata (counts, types, badges) — matches Finder "Detail".
    /// Monospaced digits so right-aligned counts (40 / 51 / 2) align cleanly.
    static let trailingFont = TypographyTokens.detail.monospacedDigit()
    /// Section header font (Finder-style: 11pt, bold).
    static let sectionHeaderFont = TypographyTokens.detail.weight(.bold)
    /// The server's name at the top of its card: bold 13pt (tree style S1).
    static let serverHeaderFont = TypographyTokens.standard.weight(.bold)
    /// Server-level section headings (Databases, Security…): 11pt semibold.
    static let sectionHeadingFont = TypographyTokens.detail.weight(.semibold)
    /// Per-level indentation step — 14pt per tree level (Design/05-components.md › Explorer tree, style S1).
    static let indentStep: CGFloat = SpacingTokens.sm2 // 14pt
    /// Leading padding inside row content highlight area — 6pt.
    static let rowLeadingPadding: CGFloat = SpacingTokens.xxs2 // 6pt
    /// Trailing padding inside rows — 8pt (Figma: trailing 8).
    static let rowTrailingPadding: CGFloat = SpacingTokens.xs // 8pt
    /// Vertical padding for rows — 4pt top/bottom (Figma: top 4, bottom 4).
    static let rowVerticalPadding: CGFloat = SpacingTokens.xxs
    /// Outer horizontal padding — selection pill inset from sidebar edges.
    static let rowOuterHorizontalPadding: CGFloat = SpacingTokens.xxs2 // 6pt
    /// Hover/selection highlight corner radius (tree style S1).
    static let hoverCornerRadius: CGFloat = LayoutTokens.Workspace.treeRowCornerRadius
    /// Spacing between major sidebar sections.
    static let sectionGroupSpacing: CGFloat = SpacingTokens.xxs

    // MARK: - Legacy aliases (use during migration, remove after)

    /// Legacy alias — use `rowLeadingPadding` in new code.
    static let rowHorizontalPadding: CGFloat = 0
}

func makeSelectStatement(
    qualifiedName: String,
    columnLines: String,
    databaseType: DatabaseType,
    limit: Int?,
    offset: Int = 0
) -> String {
    switch databaseType {
    case .microsoftSQL:
        var statement = """
SELECT
    \(columnLines)
FROM \(qualifiedName)
"""
        if let limit {
            statement += """

ORDER BY (SELECT NULL)
OFFSET \(offset) ROWS
FETCH NEXT \(limit) ROWS ONLY
"""
        }
        statement += ";"
        return statement
    case .postgresql, .mysql, .sqlite:
        var statement = """
SELECT
    \(columnLines)
FROM \(qualifiedName)
"""
        if let limit {
            statement += """

LIMIT \(limit)
"""
            if offset > 0 {
                statement += """

OFFSET \(offset)
"""
            }
        } else if offset > 0 {
            statement += """

OFFSET \(offset)
"""
        }
        statement += ";"
        return statement
    }
}

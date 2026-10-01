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

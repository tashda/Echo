import SwiftUI

struct HoveredExplorerRowIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
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
}

enum ExplorerColumnMetrics {
    /// Hierarchy depth for column rows (nested under objects at depth 3).
    static let depth: Int = 4
    static let highlightExtension: CGFloat = SpacingTokens.xs2
    static let iconSize: CGFloat = SpacingTokens.md
    static let spacing: CGFloat = SpacingTokens.xs
}

/// Shared constants for sidebar row consistency (macOS Finder sidebar aesthetic).
///
/// Measured from macOS 26 Finder sidebar (Medium size):
/// - 13pt text, 20pt icon frame, ~28pt row height
/// - 18pt indentation per tree level
/// - Fixed 12pt disclosure column (always present for alignment)
/// - Selection pill inset 8pt from sidebar edges, 8pt corner radius
/// - All icons monochrome secondary gray, same visual weight
enum SidebarRowConstants {
    /// Chevron font — matches Finder disclosure triangles.
    static let chevronFont = Font.system(size: 9, weight: .bold)
    /// Fixed-width disclosure column — always present for icon alignment.
    static let chevronWidth: CGFloat = SpacingTokens.sm
    /// Icon font — 16pt regular weight, renders ~18pt visual icons in a 20pt frame.
    static let iconFont = Font.system(size: 16, weight: .regular)
    /// Icon frame size — 20pt square, matches Finder medium sidebar.
    static let iconFrame: CGFloat = SpacingTokens.md2
    /// Spacing between icon and text label.
    static let iconTextSpacing: CGFloat = SpacingTokens.xxs2
    /// Primary label font — 13pt system, regular weight.
    static let labelFont = TypographyTokens.standard
    /// Font for trailing metadata (counts, types, badges) — matches Finder "Detail".
    static let trailingFont = TypographyTokens.detail
    /// Section header font (Finder-style: 11pt, bold).
    static let sectionHeaderFont = TypographyTokens.detail.weight(.bold)
    /// Per-level indentation step — 18pt per tree level.
    static let indentStep: CGFloat = SpacingTokens.md1
    /// Leading padding inside row content.
    static let rowLeadingPadding: CGFloat = SpacingTokens.xxs
    /// Trailing padding inside rows.
    static let rowTrailingPadding: CGFloat = SpacingTokens.sm
    /// Vertical padding for rows — 3pt top/bottom for ~28pt total height.
    static let rowVerticalPadding: CGFloat = 3
    /// Outer horizontal padding — selection pill inset from sidebar edges.
    static let rowOuterHorizontalPadding: CGFloat = SpacingTokens.xs
    /// Hover/selection highlight corner radius.
    static let hoverCornerRadius: CGFloat = SpacingTokens.xs
    /// Spacing between major sidebar sections.
    static let sectionGroupSpacing: CGFloat = SpacingTokens.xxs

    // MARK: - Legacy aliases (use during migration, remove after)

    /// Legacy alias — use `rowLeadingPadding` in new code.
    static let rowHorizontalPadding: CGFloat = rowLeadingPadding
}

enum ExplorerSidebarPalette {
    static let monochrome = ColorTokens.Text.primary

    static let database = ColorTokens.Explorer.database
    static let tables = ColorTokens.Explorer.tables
    static let views = ColorTokens.Explorer.views
    static let functions = ColorTokens.Explorer.functions
    static let jobs = ColorTokens.Explorer.jobs
    static let security = ColorTokens.Explorer.security
    static let extensions = ColorTokens.Explorer.extensions
    static let linkedServers = ColorTokens.Explorer.linkedServers

    static func folderIconColor(title: String, colored: Bool = true) -> Color {
        guard colored else { return monochrome }
        switch title {
        case "Databases": return database
        case "Agent Jobs": return jobs
        case "Security": return security
        case "Extensions": return extensions
        case "Linked Servers": return linkedServers
        default: return monochrome
        }
    }

    static func objectGroupIconColor(for type: SchemaObjectInfo.ObjectType, colored: Bool = true) -> Color {
        guard colored else { return monochrome }
        switch type {
        case .table: return tables
        case .view, .materializedView: return views
        case .function, .procedure: return functions
        case .trigger: return functions
        case .extension: return extensions
        }
    }
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

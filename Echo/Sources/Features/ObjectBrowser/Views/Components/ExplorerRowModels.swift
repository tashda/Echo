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
    static let contentLeading: CGFloat = SpacingTokens.lg
    static let highlightExtension: CGFloat = SpacingTokens.xs2
    static let iconSize: CGFloat = SpacingTokens.md
    static let spacing: CGFloat = SpacingTokens.xs
}

/// Shared constants for sidebar row consistency (macOS 26 Tahoe sidebar aesthetic).
enum SidebarRowConstants {
    /// Chevron font — uniform across all disclosure triangles.
    static let chevronFont = TypographyTokens.compact.weight(.medium)
    /// Chevron frame width.
    static let chevronWidth: CGFloat = SpacingTokens.xs2
    /// Icon font for sidebar row icons.
    static let iconFont = TypographyTokens.prominent
    /// Icon frame size (all sidebar icons).
    static let iconFrame: CGFloat = SpacingTokens.md2
    /// Spacing between icon and text label.
    static let iconTextSpacing: CGFloat = SpacingTokens.xs
    /// Per-level indentation step.
    static let indentStep: CGFloat = SpacingTokens.xs
    /// Horizontal padding inside rows (leading).
    static let rowHorizontalPadding: CGFloat = SpacingTokens.xxxs
    /// Trailing padding inside rows (accounts for scrollbar overlap).
    static let rowTrailingPadding: CGFloat = SpacingTokens.xs
    /// Vertical padding for structural rows.
    static let rowVerticalPadding: CGFloat = SpacingTokens.xxs2
    /// Hover highlight corner radius.
    static let hoverCornerRadius: CGFloat = SpacingTokens.xs
    /// Spacing between major sidebar sections for visual grouping.
    static let sectionGroupSpacing: CGFloat = SpacingTokens.xs
}

enum ExplorerSidebarPalette {
    static let monochrome = ColorTokens.Text.secondary

    static let database = ColorTokens.Explorer.database
    static let tables = ColorTokens.Explorer.tables
    static let views = ColorTokens.Explorer.views
    static let functions = ColorTokens.Explorer.functions
    static let jobs = ColorTokens.Explorer.jobs
    static let security = ColorTokens.Explorer.security
    static let extensions = ColorTokens.Explorer.extensions

    static func folderIconColor(title: String, colored: Bool = true) -> Color {
        guard colored else { return monochrome }
        switch title {
        case "Databases": return database
        case "Agent Jobs": return jobs
        case "Security": return security
        case "Extensions": return extensions
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

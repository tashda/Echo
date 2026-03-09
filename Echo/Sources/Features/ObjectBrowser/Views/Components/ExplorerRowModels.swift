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
    static let contentLeading: CGFloat = 24
    static let highlightExtension: CGFloat = 10
    static let iconSize: CGFloat = 16
    static let spacing: CGFloat = 8
}

/// Shared constants for sidebar row consistency (Xcode navigator aesthetic).
enum SidebarRowConstants {
    /// Chevron font — uniform across all disclosure triangles.
    static let chevronFont = Font.system(size: 10, weight: .medium)
    /// Chevron frame width.
    static let chevronWidth: CGFloat = 10
    /// Icon frame size (all sidebar icons).
    static let iconFrame: CGFloat = 16
    /// Per-level indentation step.
    static let indentStep: CGFloat = 12  // SpacingTokens.sm
    /// Horizontal padding inside rows.
    static let rowHorizontalPadding: CGFloat = 8  // SpacingTokens.xs
    /// Vertical padding for structural rows.
    static let rowVerticalPadding: CGFloat = 4  // SpacingTokens.xxs
    /// Hover highlight corner radius.
    static let hoverCornerRadius: CGFloat = 4
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

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

/// Shared constants for sidebar row consistency (macOS 26 Tahoe Finder sidebar aesthetic).
///
/// Measured from macOS 26 Tahoe Finder sidebar (Medium size):
/// - 13pt text, 20pt icon frame, ~28pt row height
/// - 18pt indentation per tree level
/// - Fixed 16pt disclosure column (always present for alignment)
/// - Selection pill inset 8pt from sidebar edges, 10pt corner radius
/// - All icons monochrome secondary gray, Medium visual weight
enum SidebarRowConstants {
    /// Chevron font — matches Finder disclosure triangles.
    static let chevronFont = Font.system(size: 9, weight: .semibold)
    /// Fixed-width disclosure column — always present for icon alignment.
    static let chevronWidth: CGFloat = SpacingTokens.md // 16pt
    /// Icon font — Medium weight, renders within 18×16pt frame.
    static let iconFont = Font.system(size: 14, weight: .medium)
    /// Icon frame width — 18pt (Figma: W 18).
    static let iconFrameWidth: CGFloat = SpacingTokens.md1 // 18pt
    /// Icon frame height — 16pt (Figma: H 16).
    static let iconFrameHeight: CGFloat = SpacingTokens.md // 16pt
    /// Legacy square frame — use iconFrameWidth/iconFrameHeight instead.
    static let iconFrame: CGFloat = SpacingTokens.md1 // 18pt (width)
    /// Spacing between icon and text label — 6pt (Figma: gap 6).
    static let iconTextSpacing: CGFloat = SpacingTokens.xxs2 // 6pt
    /// Primary label font — 11pt Medium (Figma: SF Pro Medium 11).
    static let labelFont = TypographyTokens.sidebarLabel
    /// Font for trailing metadata (counts, types, badges) — matches Finder "Detail".
    static let trailingFont = TypographyTokens.detail
    /// Section header font (Finder-style: 11pt, bold).
    static let sectionHeaderFont = TypographyTokens.detail.weight(.bold)
    /// Per-level indentation step — 18pt per tree level.
    static let indentStep: CGFloat = 18
    /// Leading padding inside row content highlight area — 10pt (Figma: leading 10).
    static let rowLeadingPadding: CGFloat = SpacingTokens.xs2 // 10pt
    /// Trailing padding inside rows — 8pt (Figma: trailing 8).
    static let rowTrailingPadding: CGFloat = SpacingTokens.xs // 8pt
    /// Vertical padding for rows — 4pt top/bottom (Figma: top 4, bottom 4).
    static let rowVerticalPadding: CGFloat = SpacingTokens.xxs
    /// Outer horizontal padding — selection pill inset from sidebar edges.
    static let rowOuterHorizontalPadding: CGFloat = SpacingTokens.xs
    /// Hover/selection highlight corner radius — 8pt (Figma: corner radius 8).
    static let hoverCornerRadius: CGFloat = SpacingTokens.xs // 8pt
    /// Spacing between major sidebar sections.
    static let sectionGroupSpacing: CGFloat = SpacingTokens.xxs

    // MARK: - Legacy aliases (use during migration, remove after)

    /// Legacy alias — use `rowLeadingPadding` in new code.
    static let rowHorizontalPadding: CGFloat = 0
}

enum ExplorerSidebarPalette {
    static let monochrome = ColorTokens.Text.secondary

    static let databaseFolder = ColorTokens.Explorer.databaseFolder
    static let databaseInstance = ColorTokens.Explorer.databaseInstance
    static let tables = ColorTokens.Explorer.tables
    static let views = ColorTokens.Explorer.views
    static let materializedViews = ColorTokens.Explorer.materializedViews
    static let functions = ColorTokens.Explorer.functions
    static let procedures = ColorTokens.Explorer.procedures
    static let triggers = ColorTokens.Explorer.triggers
    static let jobs = ColorTokens.Explorer.jobs
    static let security = ColorTokens.Explorer.security
    static let queryStore = ColorTokens.Explorer.queryStore
    static let users = ColorTokens.Explorer.users
    static let roles = ColorTokens.Explorer.roles
    static let logins = ColorTokens.Explorer.logins
    static let serverRoles = ColorTokens.Explorer.serverRoles
    static let credentials = ColorTokens.Explorer.credentials
    static let extensions = ColorTokens.Explorer.extensions
    static let linkedServers = ColorTokens.Explorer.linkedServers
    
    // Management Colors
    static let management = ColorTokens.Explorer.management
    static let extendedEvents = ColorTokens.Explorer.extendedEvents
    static let databaseMail = ColorTokens.Explorer.databaseMail
    static let activityMonitor = ColorTokens.Explorer.activityMonitor

    static func folderIconColor(title: String, colored: Bool = true) -> Color {
        guard colored else { return monochrome }
        switch title {
        case "Databases": return databaseFolder
        case "Agent Jobs", "Agent Jobs Overview": return jobs
        case "Security": return security
        case "Users": return users
        case "Database Roles", "Application Roles", "Schemas", "Group Roles": return roles
        case "Logins", "Login Roles": return logins
        case "Server Roles": return serverRoles
        case "Credentials": return credentials
        case "Management": return management
        case "Extended Events": return extendedEvents
        case "Database Mail": return databaseMail
        case "Activity Monitor": return activityMonitor
        case "Query Store": return queryStore
        case "Extensions": return extensions
        case "Linked Servers": return linkedServers
        default: return monochrome
        }
    }

    static func objectGroupIconColor(for type: SchemaObjectInfo.ObjectType, colored: Bool = true) -> Color {
        guard colored else { return monochrome }
        switch type {
        case .table: return tables
        case .view: return views
        case .materializedView: return materializedViews
        case .function: return functions
        case .procedure: return procedures
        case .trigger: return triggers
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

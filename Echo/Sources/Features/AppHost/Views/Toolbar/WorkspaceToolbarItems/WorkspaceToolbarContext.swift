import Foundation

/// Which toolbar groups the active tab needs (plan K2). The toolbar hides the rest, so groups melt
/// in and out as tabs change instead of leaving empty glass behind. A tab's own buttons (round
/// 37.5) count by shape only: whether it has a special button and how many groups, so a button
/// changing its state never rebuilds the toolbar.
struct WorkspaceToolbarContext: Equatable {
    /// Run and the editor actions (Format, Validate, Help, Plan).
    var isQuery = false
    /// SQLCMD and Statistics, for SQL Server query tabs.
    var hasDatabaseToggles = false
    /// Refresh, only while the front tab can reload (round 34, RL1).
    var canReload = false
    /// Open in New Window, for a tool that can live in a window of its own (Agent Jobs).
    var canOpenInWindow = false
    /// The front tab's special button (Start Trace, New Backup…), round 37.5.
    var hasTabSpecial = false
    /// How many groups of its other buttons the front tab has, up to `maxTabGroups`.
    var tabGroupCount = 0

    static let maxTabGroups = 3

    init(kind: WorkspaceTab.Kind?, databaseType: DatabaseType?, section: TabToolbarSection? = nil) {
        guard let kind else { return }
        canReload = TabReloader.canReload(kind)
        canOpenInWindow = kind == .jobQueue
        if kind == .query {
            isQuery = true
            hasDatabaseToggles = databaseType == .microsoftSQL
        }
        if let section {
            hasTabSpecial = section.special != nil
            tabGroupCount = min(section.groups.filter { !$0.isEmpty }.count, Self.maxTabGroups)
        }
    }
}

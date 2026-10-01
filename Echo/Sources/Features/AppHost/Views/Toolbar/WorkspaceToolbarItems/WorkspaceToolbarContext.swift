import Foundation

/// Which toolbar groups the active tab needs (plan K2). The toolbar hides the rest, so groups melt
/// in and out as tabs change instead of leaving empty glass behind.
/// Tool tabs add nothing: their actions live in the tab (round 45).
struct WorkspaceToolbarContext: Equatable {
    /// Run and the editor actions (Format, Validate, Help, Plan).
    var isQuery = false
    /// SQLCMD and Statistics, for SQL Server query tabs.
    var hasDatabaseToggles = false
    /// Refresh, only while the front tab can reload (round 34, RL1).
    var canReload = false
    /// Open in New Window, for a tool that can live in a window of its own (Agent Jobs).
    var canOpenInWindow = false

    init(kind: WorkspaceTab.Kind?, databaseType: DatabaseType?) {
        guard let kind else { return }
        canReload = TabReloader.canReload(kind)
        canOpenInWindow = kind == .jobQueue
        if kind == .query {
            isQuery = true
            hasDatabaseToggles = databaseType == .microsoftSQL
        }
    }
}

import Foundation

/// Which toolbar groups the active tab needs (plan K2). The toolbar hides the rest, so groups melt
/// in and out as tabs change instead of leaving empty glass behind.
struct WorkspaceToolbarContext: Equatable {
    /// The one contextual capsule next to Run: Structure, Activity Monitor, Job Queue, Error Log
    /// and maintenance tools.
    var hasTabTools = false
    /// Run and the editor actions (Format, Validate, Help, Plan).
    var isQuery = false
    /// SQLCMD and Statistics, for SQL Server query tabs.
    var hasDatabaseToggles = false
    /// Refresh, only while the front tab can reload (round 34, RL1).
    var canReload = false

    init(kind: WorkspaceTab.Kind?, databaseType: DatabaseType?) {
        guard let kind else { return }
        canReload = TabReloader.canReload(kind)
        switch kind {
        case .query:
            isQuery = true
            hasDatabaseToggles = databaseType == .microsoftSQL
        case .structure, .activityMonitor, .jobQueue, .errorLog, .maintenance, .mssqlMaintenance:
            hasTabTools = true
        default:
            break
        }
    }
}

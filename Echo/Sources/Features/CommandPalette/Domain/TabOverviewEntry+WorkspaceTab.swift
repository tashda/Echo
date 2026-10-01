import Foundation

@MainActor
extension TabOverviewEntry {
    /// The overview's rows for a window's tabs, in strip order.
    static func entries(for tabs: [WorkspaceTab]) -> [TabOverviewEntry] {
        tabs.map { tab in
            let connection = tab.connection
            let server = connection.connectionName.isEmpty ? connection.host : connection.connectionName
            let database = tab.activeDatabaseName
            let detail = tab.kind == .query
                ? (database ?? "")
                : [tab.kind.displayName, database].compactMap { $0 }.joined(separator: " · ")
            let firstLine = tab.query?.sql.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            return TabOverviewEntry(id: tab.id, title: tab.title, server: server, detail: detail, keywords: firstLine)
        }
    }
}

@MainActor
extension WorkspaceTab {
    /// The query tab's state for the overview; nil for a tool tab.
    var overviewStatus: TabOverviewStatus? {
        guard let query else { return nil }
        return TabOverviewStatus(
            isExecuting: query.isExecuting,
            elapsed: query.currentExecutionTime,
            hasError: query.errorMessage != nil,
            wasCancelled: query.wasCancelled,
            hasRun: query.hasExecutedAtLeastOnce,
            rows: query.rowProgress.displayCount
        )
    }
}

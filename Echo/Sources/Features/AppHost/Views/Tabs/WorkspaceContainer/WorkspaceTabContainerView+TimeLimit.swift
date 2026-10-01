import Foundation

/// Before each run (round 21, timeouts): the limit that applies, shown in the footer (FT1), set on
/// the tab's PostgreSQL session only when it changed, and Run Without Limit for one run.
extension WorkspaceTabContainerView {
    func prepareQueryTimeLimit(tab: WorkspaceTab, queryState: QueryEditorState, sql: String) async {
        environmentState.announceQueryTimeLimitsOnce()
        let tabID = tab.id
        queryState.rerunAction = { Task { await self.runQuery(tabId: tabID, sql: sql) } }

        let withoutLimit = queryState.runWithoutLimitOnce
        queryState.runWithoutLimitOnce = false
        let limit = withoutLimit ? nil : environmentState.queryTimeLimit(for: tab.connection)
        queryState.timeLimit = limit?.seconds
        queryState.timeLimitScope = limit?.scope

        guard tab.connection.databaseType == .postgresql else { return }
        let session = tab.isAwaitingDedicatedSession ? (try? await tab.awaitDedicatedSession()) : tab.session
        guard let store = (session as? PostgresSession)?.pinnedStore else { return }
        // No Echo limit leaves the server's own (for the role or database); Run Without Limit lifts that too.
        let timeout: Duration? = withoutLimit ? .zero : limit.map { .milliseconds(Int64(($0.seconds * 1000).rounded())) }
        await store.setStatementTimeout(timeout)
    }
}

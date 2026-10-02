import SwiftUI

/// Cancel and Force Stop for a running query tab (Echo Labs rounds 21 and 22).
extension WorkspaceTabContainerView {
    func cancelQuery(tabId: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }
        guard tab.connection.databaseType == .postgresql else {
            if let session = tab.session as? MSSQLDedicatedQuerySession {
                cancelSQLServerQuery(queryState: queryState, session: session)
            } else if let session = tab.session as? MySQLSession {
                cancelMySQLQuery(queryState: queryState, session: session)
            } else {
                queryState.cancelExecution()
            }
            return
        }
        // PostgreSQL: stop the statement on the server first (otherwise it keeps running and the
        // connection stays busy draining rows), then cancel the task. The "canceling statement"
        // error that follows is treated as a cancellation because the request flag is already set.
        guard queryState.cancelPhase == nil else { return }
        queryState.isCancellationRequested = true
        queryState.cancelPhase = .cancelling
        let session = tab.session
        Task { @MainActor in
            _ = await session.cancelRunningQuery()
            queryState.cancelExecution()
            await followPostgresCancel(queryState: queryState, session: session)
        }
    }

    /// SQL Server: cancelling the task cancels the statement on the server and keeps the session
    /// (round 22, CL1), and looks like the PostgreSQL cancel (Cancelling, Force Stop after 5 s).
    /// Tabs run with XACT_ABORT ON, so SQL Server rolls back a transaction the cancelled statement
    /// was in; say so (XA1).
    private func cancelSQLServerQuery(queryState: QueryEditorState, session: MSSQLDedicatedQuerySession) {
        guard queryState.cancelPhase == nil else { return }
        let transactionWasOpen = session.isInTransaction
        queryState.isCancellationRequested = true
        queryState.cancelPhase = .cancelling
        queryState.cancelExecution()
        Task { @MainActor in
            await followCancel(queryState: queryState) { await session.forceStopRunningQuery() }
            // After a Force Stop the connection is closed and still reports the transaction, so
            // this note only follows a cancel that SQL Server acknowledged.
            guard transactionWasOpen, queryState.wasCancelled, !session.isInTransaction else { return }
            queryState.appendMessage(
                message: "Transaction rolled back: the cancelled statement was inside a transaction, and SQL Server rolled it back (XACT_ABORT is on).",
                severity: .warning,
                category: "Transaction"
            )
        }
    }

    /// MySQL and MariaDB: KILL QUERY stops the statement on the server and keeps the connection, so
    /// the run ends with the server's "interrupted" answer; like PostgreSQL, Force Stop after 5 s.
    /// The transaction stays open (only the statement is rolled back), and the footer shows it.
    /// The task is cancelled only when KILL QUERY could not be sent: that closes the connection.
    private func cancelMySQLQuery(queryState: QueryEditorState, session: MySQLSession) {
        guard queryState.cancelPhase == nil else { return }
        queryState.isCancellationRequested = true
        queryState.cancelPhase = .cancelling
        Task { @MainActor in
            if await !session.cancelRunningQuery() { queryState.cancelExecution() }
            await followCancel(queryState: queryState) { await session.forceStopRunningQuery() }
        }
    }

    /// Round 21, cancel: offers Force Stop when the server hasn't stopped within 5 s (CS2), and says
    /// when the cancelled statement left its transaction needing ROLLBACK (TX1).
    private func followPostgresCancel(queryState: QueryEditorState, session: DatabaseSession) async {
        await followCancel(queryState: queryState) {
            await (session as? PostgresSession)?.forceStopRunningQuery() ?? (stopped: false, transactionWasOpen: false)
        }
        if queryState.wasCancelled, await (session as? PostgresSession)?.isInFailedTransaction() == true {
            queryState.noteCancelledInsideTransaction()
        }
    }

    /// Waits for the cancelled run to end, offering Force Stop when the server hasn't stopped
    /// within 5 s (round 21, CS2). `forceStop` closes the tab's connection.
    private func followCancel(
        queryState: QueryEditorState,
        forceStop: @escaping @MainActor () async -> (stopped: Bool, transactionWasOpen: Bool)
    ) async {
        let started = ContinuousClock.now
        while queryState.isExecuting {
            if queryState.cancelPhase == .cancelling, ContinuousClock.now - started >= QueryCancelPhase.forceStopDelay {
                queryState.cancelPhase = .notStopping
                queryState.forceStopHandler = { [weak queryState] in
                    guard let queryState else { return }
                    queryState.forceStopHandler = nil
                    Task { @MainActor in
                        let outcome = await forceStop()
                        if outcome.stopped { queryState.noteForceStopped(transactionWasOpen: outcome.transactionWasOpen) }
                        queryState.cancelExecution()
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}

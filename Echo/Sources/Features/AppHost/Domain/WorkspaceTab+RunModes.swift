import Foundation
import SwiftUI

/// Running a query tab in each `QueryRunMode`, shared by the toolbar's Run and the Query menu.
extension WorkspaceTab {
    var canRunQuery: Bool {
        guard let query else { return false }
        return !query.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var supportsExecutionPlans: Bool { session is ExecutionPlanProviding }

    /// Query › Run as One Transaction (round 21, OT1) applies to PostgreSQL scripts.
    var supportsRunAsOneTransaction: Bool { connection.databaseType == .postgresql && query != nil }

    /// The Run as One Transaction toggle for menus: off by default, per tab.
    var runAsOneTransactionBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.query?.runsScriptAsOneTransaction ?? false },
            set: { [weak self] in self?.query?.runsScriptAsOneTransaction = $0 }
        )
    }

    func canRun(_ mode: QueryRunMode) -> Bool {
        guard canRunQuery, let query, !query.isExecuting else { return false }
        switch mode {
        case .run, .statementAtCursor: return true
        case .explain, .explainAnalyze: return supportsExecutionPlans && !query.isLoadingExecutionPlan
        }
    }

    func run(_ mode: QueryRunMode) {
        guard canRun(mode), let query else { return }
        switch mode {
        case .run:
            let sql = query.hasActiveSelection ? query.selectedText : query.sql
            guard let action = executeQueryAction else { return }
            query.lastRunRange = query.hasActiveSelection ? query.selectionRange : NSRange(location: 0, length: (query.sql as NSString).length)
            Task { await action(sql) }
        case .statementAtCursor:
            guard let statement = SQLStatementAtCaret.statement(in: query.sql, caret: query.caretLocation),
                  let action = executeQueryAction else { return }
            query.lastRunRange = statement.range
            Task { await action(statement.text) }
        case .explain:
            let sql = query.hasActiveSelection ? query.selectedText : query.sql
            Task { await requestExecutionPlan(sql: sql, actual: false) }
        case .explainAnalyze:
            let sql = query.hasActiveSelection ? query.selectedText : query.sql
            Task { await requestExecutionPlan(sql: sql, actual: true) }
        }
    }

    /// Fetches the estimated plan, or runs the query for the actual plan and its results, and shows
    /// the plan pane.
    func requestExecutionPlan(sql: String, actual: Bool) async {
        guard let query, let planProvider = session as? ExecutionPlanProviding else { return }
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSQL.isEmpty else { return }

        var effectiveSQL = trimmedSQL
        if connection.databaseType == .microsoftSQL, let database = activeDatabaseName, !database.isEmpty {
            effectiveSQL = "USE [\(database)];\n\(effectiveSQL)"
        }

        query.isLoadingExecutionPlan = true
        query.executionPlan = nil
        panelState.isOpen = true
        panelState.selectedSegment = .executionPlan
        if actual { query.startExecution() }

        do {
            if actual {
                let (result, plan) = try await planProvider.getActualExecutionPlan(effectiveSQL)
                query.consumeFinalResult(result)
                query.executionPlan = plan
                query.finishExecution()
            } else {
                query.executionPlan = try await planProvider.getEstimatedExecutionPlan(effectiveSQL)
            }
            query.isLoadingExecutionPlan = false
            query.appendMessage(
                message: actual ? "Actual execution plan generated" : "Estimated execution plan generated",
                severity: .info,
                category: "Execution Plan"
            )
        } catch {
            query.isLoadingExecutionPlan = false
            if actual { query.failExecution(with: error.localizedDescription) }
            query.appendMessage(
                message: "Failed to generate execution plan: \(error.localizedDescription)",
                severity: .error,
                category: "Execution Plan"
            )
        }
    }
}

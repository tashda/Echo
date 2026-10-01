import Foundation

/// A finished PostgreSQL script (Echo Labs round 21, script results, accepted): one Messages line
/// per statement (SP2), the statement list's entries (SR4, SL3, SC2) and the editor link (SK2).
extension WorkspaceTabContainerView {
    func consumePostgresScript(_ run: PostgresScriptRun, statements: [String], into state: QueryEditorState) {
        let ranges = ScriptResultEntry.editorRanges(for: statements, in: state.sql, within: state.lastRunRange)
        let entries = ScriptResultEntry.entries(for: run.results, statements: statements, editorRanges: ranges)

        // Round 41.4 (ML1): each statement's line under its own heading; the summary under the run's.
        // Each statement's notices (RAISE NOTICE …, Echo #37) come before its line.
        let runStatement = state.messageStatement
        for entry in entries {
            state.messageStatement = entry.editorRange.flatMap { QueryMessageStatement.heading(for: state.sql, range: $0) } ?? runStatement
            for notice in run.results.first(where: { $0.batchIndex == entry.id })?.messages ?? [] where notice.category != "Server Response" {
                state.appendServerMessage(notice)
            }
            state.appendMessage(message: entry.messageLine, severity: entry.isFailure ? .error : .info, category: "Script")
        }
        state.messageStatement = runStatement
        for line in PostgresScriptSummary.lines(results: run.results, transaction: run.transaction) {
            state.appendMessage(message: line.text, severity: line.isError ? .error : .info, category: "Script")
        }

        let sets = run.results.flatMap(\.resultSets)
        if let primary = sets.first {
            state.consumeFinalResult(QueryResultSet(
                columns: primary.columns,
                rows: primary.rows,
                totalRowCount: primary.totalRowCount,
                commandTag: primary.commandTag,
                additionalResults: Array(sets.dropFirst()),
                dataClassification: primary.dataClassification,
                serverMessages: primary.serverMessages
            ))
        } else {
            state.consumeFinalResult(QueryResultSet(columns: [], rows: [], totalRowCount: 0))
        }

        guard entries.count > 1 else { return }
        state.scriptEntries = entries
        let first = entries.first { if case .rows = $0.outcome { true } else { false } } ?? entries.first { $0.isFailure } ?? entries[0]
        state.selectScriptEntry(first)
    }
}

/// The closing Messages lines of a script: what did not run, and what happened to its transaction.
nonisolated enum PostgresScriptSummary {
    struct Line: Equatable { let text: String; let isError: Bool }

    static func lines(results: [BatchResult], transaction: PostgresScriptTransaction) -> [Line] {
        var lines: [Line] = []
        let skipped = results.filter(\.skipped).map { $0.batchIndex + 1 }
        if let failed = results.first(where: { $0.error != nil }), !skipped.isEmpty {
            lines.append(Line(text: "Stopped: statement \(failed.batchIndex + 1) failed; \(numbers(skipped)) not run.", isError: true))
        }
        switch transaction {
        case .notRequested:
            break
        case .committed:
            lines.append(Line(text: "Ran as one transaction: committed.", isError: false))
        case .rolledBack(let failedStatement):
            lines.append(Line(text: "Ran as one transaction: rolled back because statement \(failedStatement + 1) failed. Nothing was saved.", isError: true))
        case .scriptManagesItsOwn:
            lines.append(Line(text: "Run as One Transaction is on, but the script has its own BEGIN, COMMIT or ROLLBACK, so it ran as written.", isError: false))
        }
        return lines
    }

    /// `statement 5 was`, `statements 5 and 6 were`, `statements 5 to 9 were`.
    static func numbers(_ values: [Int]) -> String {
        guard let first = values.first, let last = values.last else { return "" }
        switch values.count {
        case 1: return "statement \(first) was"
        case 2: return "statements \(first) and \(last) were"
        default: return "statements \(first) to \(last) were"
        }
    }
}

extension BatchProgressEvent {
    var isStreamUpdate: Bool {
        if case .streamUpdate = self { return true }
        return false
    }
}

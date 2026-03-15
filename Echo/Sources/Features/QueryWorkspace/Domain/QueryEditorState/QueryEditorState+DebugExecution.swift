import Foundation

extension QueryEditorState {

    // MARK: - Debug Session Lifecycle

    func startDebugSession() {
        let statements = TSQLStatementSplitter.split(sql)
        guard !statements.isEmpty else {
            debugPhase = .failed("No executable statements found")
            return
        }

        debugStatements = statements
        debugCurrentIndex = 0
        debugVariables.removeAll()
        debugPhase = .paused(atIndex: 0)
        debugMode = true

        messages.removeAll()
        appendMessage(
            message: "Debug session started — \(statements.count) statement\(statements.count == 1 ? "" : "s") detected",
            severity: .debug
        )
    }

    func stopDebugSession() {
        debugMode = false
        debugPhase = .idle
        debugStatements.removeAll()
        debugCurrentIndex = 0
        debugVariables.removeAll()

        // Resume any suspended continuation so the task can complete
        if let continuation = debugContinuation {
            debugContinuation = nil
            continuation.resume()
        }

        appendMessage(message: "Debug session stopped", severity: .debug)
    }

    /// Signal the debug session to proceed past a breakpoint pause.
    func debugResume() {
        guard let continuation = debugContinuation else { return }
        debugContinuation = nil
        continuation.resume()
    }

    // MARK: - Breakpoint Management

    func toggleBreakpoint(atLine line: Int) {
        let bp = DebugBreakpoint(lineNumber: line)
        if debugBreakpoints.contains(bp) {
            debugBreakpoints.remove(bp)
        } else {
            debugBreakpoints.insert(bp)
        }
    }

    func hasBreakpoint(atLine line: Int) -> Bool {
        debugBreakpoints.contains(DebugBreakpoint(lineNumber: line))
    }

    func clearAllBreakpoints() {
        debugBreakpoints.removeAll()
    }

    // MARK: - Debug Statement Helpers

    /// The statement currently being inspected in debug mode.
    var currentDebugStatement: TSQLStatementSplitter.Statement? {
        guard debugCurrentIndex >= 0, debugCurrentIndex < debugStatements.count else { return nil }
        return debugStatements[debugCurrentIndex]
    }

    /// Whether the debug session is paused and waiting for user input.
    var isDebugPaused: Bool {
        if case .paused = debugPhase { return true }
        return false
    }

    /// Whether the debugger is actively running a statement.
    var isDebugRunning: Bool {
        debugPhase == .running
    }

    /// Builds a SELECT query to inspect the current values of all known variables.
    func buildVariableInspectionQuery() -> String? {
        let variables = TSQLStatementSplitter.extractVariables(from: sql)
        guard !variables.isEmpty else { return nil }

        // Only inspect variables that have been declared in statements up to the current index
        let executedSQL = debugStatements[0...debugCurrentIndex].map(\.text).joined(separator: "\n")
        let executedVariables = TSQLStatementSplitter.extractVariables(from: executedSQL)
        guard !executedVariables.isEmpty else { return nil }

        let selects = executedVariables.map { variable in
            "\(variable.name) AS [\(variable.name)]"
        }
        return "SELECT " + selects.joined(separator: ", ")
    }

    /// Update debug variable values from a query result.
    func applyVariableInspection(_ result: QueryResultSet) {
        var updated: [DebugVariable] = []
        for column in result.columns {
            let value: String
            if let row = result.rows.first,
               let colIdx = result.columns.firstIndex(where: { $0.name == column.name }),
               colIdx < row.count {
                value = row[colIdx] ?? "NULL"
            } else {
                value = "NULL"
            }
            updated.append(DebugVariable(
                name: column.name,
                value: value,
                statementIndex: debugCurrentIndex
            ))
        }
        debugVariables = updated
    }
}

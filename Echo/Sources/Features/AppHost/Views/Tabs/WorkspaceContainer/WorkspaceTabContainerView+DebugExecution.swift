import SwiftUI

extension WorkspaceTabContainerView {

    /// Executes a debug session: splits the SQL into statements, executes each one
    /// sequentially, inspects variables, and pauses at breakpoints.
    func runDebugSession(tabId: UUID, sql: String) async {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }

        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSQL.isEmpty else { return }

        // Resolve the execution session
        let executionSession: DatabaseSession
        if tab.connection.databaseType == .postgresql,
           let activeDB = tab.activeDatabaseName, !activeDB.isEmpty {
            executionSession = (try? await tab.session.sessionForDatabase(activeDB)) ?? tab.session
        } else {
            executionSession = tab.session
        }

        await MainActor.run {
            queryState.startDebugSession()
        }

        let statements = await MainActor.run { queryState.debugStatements }
        guard !statements.isEmpty else { return }

        // Build the preamble for MSSQL (USE database, etc.)
        var preamble = ""
        if tab.connection.databaseType == .microsoftSQL,
           let selectedDB = tab.activeDatabaseName, !selectedDB.isEmpty {
            preamble = "USE [\(selectedDB)];\n"
        }

        // Accumulate executed SQL for variable scoping — variables must persist across statements
        var accumulatedSQL = preamble
        let task = Task { [weak queryState] in
            guard let state = await MainActor.run(body: { queryState }) else { return }

            for (index, statement) in statements.enumerated() {
                guard !Task.isCancelled else { break }

                let phase = await MainActor.run { state.debugPhase }
                if case .idle = phase { break }

                // Check for breakpoint at this statement's line
                let hasBreakpoint = await MainActor.run {
                    state.hasBreakpoint(atLine: statement.lineNumber)
                }

                if hasBreakpoint || index == 0 {
                    // Pause at breakpoints (and always at the first statement)
                    await MainActor.run {
                        state.debugCurrentIndex = index
                        state.debugPhase = .paused(atIndex: index)
                        state.appendMessage(
                            message: "Paused at statement \(index + 1) (line \(statement.lineNumber))",
                            severity: .debug,
                            category: "Debug",
                            line: statement.lineNumber
                        )
                    }

                    // Wait for user to continue
                    await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            state.debugContinuation = continuation
                        }
                    }
                }

                guard !Task.isCancelled else { break }

                // Execute the statement
                await MainActor.run {
                    state.debugCurrentIndex = index
                    state.debugPhase = .running
                    state.appendMessage(
                        message: "Executing statement \(index + 1): \(statementPreview(statement.text))",
                        severity: .info,
                        category: "Debug",
                        line: statement.lineNumber
                    )
                }

                do {
                    let effectiveSQL = accumulatedSQL + statement.text
                    let result = try await executionSession.simpleQuery(effectiveSQL)

                    // Append this statement to accumulated context
                    accumulatedSQL += statement.text + ";\n"

                    await MainActor.run {
                        // Show results/messages for this statement
                        if !result.rows.isEmpty {
                            state.appendMessage(
                                message: "Returned \(result.rows.count) row\(result.rows.count == 1 ? "" : "s")",
                                severity: .info,
                                category: "Debug",
                                line: statement.lineNumber,
                                metadata: ["rows": "\(result.rows.count)"]
                            )
                            // Store the result for display
                            state.consumeFinalResult(result)
                        } else if let tag = result.commandTag, !tag.isEmpty {
                            state.appendMessage(
                                message: tag,
                                severity: .info,
                                category: "Debug",
                                line: statement.lineNumber
                            )
                        }

                        // Surface server messages (PRINT, RAISERROR with severity <= 10, etc.)
                        for serverMsg in result.serverMessages {
                            let severity: QueryExecutionMessage.Severity = serverMsg.kind == .error ? .error : .info
                            state.appendMessage(
                                message: serverMsg.message,
                                severity: severity,
                                category: "Debug",
                                line: serverMsg.lineNumber.map(Int.init)
                            )
                        }
                    }

                    // Inspect variables after execution
                    await inspectDebugVariables(state: state, session: executionSession, preamble: preamble, accumulatedSQL: accumulatedSQL)

                } catch is CancellationError {
                    break
                } catch {
                    await MainActor.run {
                        state.debugPhase = .failed(error.localizedDescription)
                        state.appendMessage(
                            message: "Statement \(index + 1) failed: \(error.localizedDescription)",
                            severity: .error,
                            category: "Debug",
                            line: statement.lineNumber
                        )
                    }
                    return
                }
            }

            guard !Task.isCancelled else {
                await MainActor.run {
                    state.stopDebugSession()
                }
                return
            }

            await MainActor.run {
                state.debugPhase = .completed
                state.appendMessage(
                    message: "Debug session completed — all statements executed",
                    severity: .success,
                    category: "Debug"
                )
            }
        }

        await MainActor.run {
            queryState.setExecutingTask(task)
        }
    }

    // MARK: - Step Over

    /// Execute the next statement and pause again. Called when the user presses "Step Over".
    func debugStepOver(tabId: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }
        queryState.debugResume()
    }

    /// Continue running until the next breakpoint or end. Called when the user presses "Continue".
    func debugContinue(tabId: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }
        // For continue, we remove the implicit "pause at every statement" behavior
        // by just resuming — the loop will check for breakpoints
        queryState.debugResume()
    }

    /// Stop the debug session.
    func debugStop(tabId: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }
        queryState.stopDebugSession()
        queryState.cancelExecution()
    }

    // MARK: - Variable Inspection

    private func inspectDebugVariables(
        state: QueryEditorState,
        session: DatabaseSession,
        preamble: String,
        accumulatedSQL: String
    ) async {
        let inspectionQuery = await MainActor.run { state.buildVariableInspectionQuery() }
        guard let query = inspectionQuery else { return }

        let fullQuery = accumulatedSQL + query
        do {
            let result = try await session.simpleQuery(fullQuery)
            await MainActor.run {
                state.applyVariableInspection(result)
            }
        } catch {
            // Variable inspection is best-effort — don't fail the debug session
            await MainActor.run {
                state.appendMessage(
                    message: "Variable inspection failed: \(error.localizedDescription)",
                    severity: .warning,
                    category: "Debug"
                )
            }
        }
    }

    // MARK: - Helpers

    private func statementPreview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: "\n").first ?? trimmed
        if firstLine.count > 60 {
            return String(firstLine.prefix(57)) + "..."
        }
        return firstLine
    }
}

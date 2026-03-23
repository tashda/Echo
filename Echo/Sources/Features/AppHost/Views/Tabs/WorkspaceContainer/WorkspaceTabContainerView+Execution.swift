import SwiftUI
import EchoSense

extension WorkspaceTabContainerView {
    func runQuery(tabId: UUID, sql: String) async {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }

        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseSQL = trimmedSQL.isEmpty ? sql : trimmedSQL

        // SQLCMD mode: preprocess directives, then rejoin batches for execution
        var effectiveSQL: String
        if tab.connection.databaseType == .microsoftSQL, queryState.sqlcmdModeEnabled {
            let processed = SQLCMDPreprocessor.process(baseSQL)
            await MainActor.run {
                for warning in processed.warnings {
                    queryState.appendMessage(message: warning, severity: .warning, category: "SQLCMD")
                }
            }
            guard !processed.batches.isEmpty else {
                await MainActor.run {
                    queryState.appendMessage(
                        message: "SQLCMD preprocessing produced no executable batches",
                        severity: .info,
                        category: "SQLCMD"
                    )
                }
                return
            }
            // Each batch must be executed separately since GO is a client-side separator.
            // Join with semicolons and newlines to form a single multi-statement batch.
            // For batches repeated via GO N, duplicates already exist in the array.
            effectiveSQL = processed.batches.joined(separator: ";\n")
        } else {
            effectiveSQL = baseSQL
        }

        // Resolve the execution session — for PostgreSQL, route through database-specific session.
        // MSSQL dedicated session wait is deferred to inside the Task so startExecution() runs immediately.
        let executionSession: DatabaseSession
        let needsDedicatedSessionWait = tab.isAwaitingDedicatedSession
        if tab.connection.databaseType == .postgresql,
           let activeDB = tab.activeDatabaseName, !activeDB.isEmpty {
            executionSession = (try? await tab.session.sessionForDatabase(activeDB)) ?? tab.session
        } else {
            executionSession = tab.session
        }

        // For pooled MSSQL sessions we still need to set database context explicitly.
        // Dedicated query tabs are already connected to their target database, and sending
        // an extra USE batch before the query creates an unnecessary multi-statement stream.
        // Prepend USE [db] only for pooled MSSQL sessions that are NOT awaiting
        // a dedicated session upgrade. Dedicated sessions connect to the target database.
        if tab.connection.databaseType == .microsoftSQL,
           let selectedDB = tab.activeDatabaseName, !selectedDB.isEmpty,
           !needsDedicatedSessionWait,
           (executionSession as? MSSQLDedicatedQuerySession) == nil {
            effectiveSQL = "USE [\(selectedDB)];\n\(effectiveSQL)"
        }

        // For MSSQL, prepend SET STATISTICS when enabled
        if tab.connection.databaseType == .microsoftSQL,
           queryState.statisticsEnabled {
            effectiveSQL = "SET STATISTICS IO ON;\nSET STATISTICS TIME ON;\n\(effectiveSQL)"
        }

        let inferredObject = inferPrimaryObjectName(from: effectiveSQL)
        await MainActor.run {
            queryState.updateClipboardObjectName(inferredObject)
        }
        let foreignKeySource = resolveSchemaAndTable(for: inferredObject, connection: tab.connection)

        let task = Task { [weak queryState] in
            guard let state = await MainActor.run(body: { queryState }) else { return }

            do {
                await MainActor.run {
                    state.recordQueryDispatched()
                    if let source = foreignKeySource {
                        state.updateForeignKeyResolutionContext(schema: source.schema, table: source.table)
                    } else {
                        state.updateForeignKeyResolutionContext(schema: nil, table: nil)
                    }
                }
                // Wait for dedicated MSSQL session if still connecting
                let resolvedSession: DatabaseSession
                if needsDedicatedSessionWait {
                    resolvedSession = await tab.awaitDedicatedSession()
                } else {
                    resolvedSession = executionSession
                }

                let perQueryMode = await MainActor.run { state.streamingModeOverride }
                let executionMode: ResultStreamingExecutionMode? = perQueryMode == .auto ? nil : perQueryMode
                let result = try await resolvedSession.simpleQuery(effectiveSQL, executionMode: executionMode) { [weak state] update in
                    guard let state else { return }

                    Task { @MainActor in
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            state.applyStreamUpdate(update)
                        }
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    state.consumeFinalResult(result)
                    state.finishExecution()

                    // Record table usage to EchoSense history so frequently
                    // queried tables rank higher in future completions.
                    let historyContext = SQLEditorCompletionContext(
                        databaseType: EchoSenseDatabaseType(tab.connection.databaseType),
                        selectedDatabase: tab.activeDatabaseName ?? tab.connection.database,
                        defaultSchema: tab.connection.databaseType == .microsoftSQL ? "dbo" : "public"
                    )
                    let historyEngine = SQLAutoCompletionEngine()
                    historyEngine.updateContext(historyContext)
                    historyEngine.recordQueryExecution(baseSQL)
                }

                // Eagerly fetch FK metadata after results arrive so first click works
                if foreignKeySource != nil {
                    if let ctx = await MainActor.run(body: { state.beginForeignKeyMappingFetch() }) {
                        let mapping = await loadForeignKeyMapping(session: executionSession, schema: ctx.schema, table: ctx.table)
                        await MainActor.run {
                            if Task.isCancelled {
                                state.failForeignKeyMappingFetch()
                            } else {
                                state.completeForeignKeyMappingFetch(with: mapping)
                            }
                        }
                    }
                }

                await MainActor.run {
                    // Surface server info messages (statistics, warnings, etc.)
                    for serverMsg in result.serverMessages {
                        let severity: QueryExecutionMessage.Severity = serverMsg.kind == .error ? .error : .info
                        state.appendMessage(
                            message: serverMsg.message,
                            severity: severity,
                            metadata: serverMsg.number != 0 ? ["msgNumber": "\(serverMsg.number)"] : [:]
                        )
                    }

                    var metadata: [String: String] = [
                        "rows": "\(result.rows.count)"
                    ]
                    let columnNames = result.columns.map(\.name).joined(separator: ", ")
                    if !columnNames.isEmpty {
                        metadata["columns"] = columnNames
                    }
                    if let commandTag = result.commandTag, !commandTag.isEmpty {
                        metadata["commandTag"] = commandTag
                    }

                    state.appendMessage(
                        message: "Returned \(result.rows.count) row\(result.rows.count == 1 ? "" : "s")",
                        severity: .info,
                        metadata: metadata
                    )
                    appState.addToQueryHistory(
                        effectiveSQL,
                        connectionID: tab.connection.id,
                        databaseName: tab.activeDatabaseName ?? tab.connection.database,
                        resultCount: result.rows.count,
                        duration: state.lastExecutionTime ?? 0
                    )

                    // Detect USE [database] in the original SQL and update tab context
                    detectAndApplyDatabaseSwitch(originalSQL: trimmedSQL, tab: tab)

                    // After DDL (CREATE/ALTER/DROP/RENAME), refresh the session's schema structure
                    // so autocomplete reflects the changes immediately.
                    if isDDL(trimmedSQL), let session = environmentState.sessionGroup.activeSessions
                        .first(where: { $0.id == tab.connectionSessionID }) {
                        Task {
                            await environmentState.refreshDatabaseStructure(for: session.id)
                        }
                    }
                }
            } catch is CancellationError {
                if let dedicatedSession = executionSession as? MSSQLDedicatedQuerySession {
                    await MainActor.run {
                        dedicatedSession.reconnectAfterCancellation()
                    }
                }
                await MainActor.run {
                    state.markCancellationCompleted()
                }
            } catch {
                let shouldTreatAsCancellation = await MainActor.run {
                    state.isCancellationRequested
                }
                if shouldTreatAsCancellation,
                   let dedicatedSession = executionSession as? MSSQLDedicatedQuerySession {
                    await MainActor.run {
                        dedicatedSession.reconnectAfterCancellation()
                    }
                }
                await MainActor.run {
                    if shouldTreatAsCancellation {
                        state.markCancellationCompleted()
                    } else {
                        state.errorMessage = error.localizedDescription
                        state.failExecution(with: "Query execution failed: \(error.localizedDescription)")
                    }
                }
            }
        }

        await MainActor.run {
            queryState.errorMessage = nil
            queryState.startExecution()
            queryState.setExecutingTask(task)
            environmentState.dataInspectorContent = nil
        }
    }

    func cancelQuery(tabId: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }
        queryState.cancelExecution()
    }

    /// Returns true if the SQL begins with a DDL statement that modifies schema objects.
    private func isDDL(_ sql: String) -> Bool {
        let upper = sql.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let ddlKeywords = ["CREATE ", "ALTER ", "DROP ", "RENAME ", "TRUNCATE ", "COMMENT "]
        return ddlKeywords.contains(where: { upper.hasPrefix($0) })
    }

    private func loadForeignKeyMapping(session: DatabaseSession, schema: String, table: String) async -> ForeignKeyMapping {
        do {
            let details = try await session.getTableStructureDetails(schema: schema, table: table)
            return buildForeignKeyMapping(from: details)
        } catch {
            return [:]
        }
    }
}

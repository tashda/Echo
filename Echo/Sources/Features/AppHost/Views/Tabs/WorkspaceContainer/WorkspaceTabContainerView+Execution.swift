import SwiftUI

extension WorkspaceTabContainerView {
    func runQuery(tabId: UUID, sql: String) async {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }

        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        var effectiveSQL = trimmedSQL.isEmpty ? sql : trimmedSQL

        // For MSSQL, prepend USE [database] to set the correct database context
        if tab.connection.databaseType == .microsoftSQL,
           let selectedDB = tab.activeDatabaseName, !selectedDB.isEmpty {
            effectiveSQL = "USE [\(selectedDB)];\n\(effectiveSQL)"
        }

        // For MSSQL, prepend SET STATISTICS when enabled
        if tab.connection.databaseType == .microsoftSQL,
           queryState.statisticsEnabled {
            effectiveSQL = "SET STATISTICS IO ON;\nSET STATISTICS TIME ON;\n\(effectiveSQL)"
        }

        // Resolve the execution session -- for PostgreSQL, route through the database-specific session
        let executionSession: DatabaseSession
        if tab.connection.databaseType == .postgresql,
           let activeDB = tab.activeDatabaseName, !activeDB.isEmpty {
            executionSession = (try? await tab.session.sessionForDatabase(activeDB)) ?? tab.session
        } else {
            executionSession = tab.session
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
                let perQueryMode = await MainActor.run { state.streamingModeOverride }
                let executionMode: ResultStreamingExecutionMode? = perQueryMode == .auto ? nil : perQueryMode
                let result = try await executionSession.simpleQuery(effectiveSQL, executionMode: executionMode) { [weak state] update in
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
                    appState.addToQueryHistory(effectiveSQL, resultCount: result.rows.count, duration: state.lastExecutionTime ?? 0)

                    // Detect USE [database] in the original SQL and update tab context
                    detectAndApplyDatabaseSwitch(originalSQL: trimmedSQL, tab: tab)
                }
            } catch is CancellationError {
                await MainActor.run {
                    state.markCancellationCompleted()
                }
            } catch {
                await MainActor.run {
                    state.errorMessage = error.localizedDescription
                    state.failExecution(with: "Query execution failed: \(error.localizedDescription)")
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

    func supportsExecutionPlan(_ tab: WorkspaceTab) -> Bool {
        tab.session is ExecutionPlanProviding
    }

    func requestEstimatedPlan(tabId: UUID, sql: String) async {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query,
              let planProvider = tab.session as? ExecutionPlanProviding else { return }

        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSQL.isEmpty else { return }

        var effectiveSQL = trimmedSQL
        if tab.connection.databaseType == .microsoftSQL,
           let selectedDB = tab.activeDatabaseName, !selectedDB.isEmpty {
            effectiveSQL = "USE [\(selectedDB)];\n\(effectiveSQL)"
        }

        await MainActor.run {
            queryState.isLoadingExecutionPlan = true
            queryState.executionPlan = nil
        }

        do {
            let plan = try await planProvider.getEstimatedExecutionPlan(effectiveSQL)
            await MainActor.run {
                queryState.executionPlan = plan
                queryState.isLoadingExecutionPlan = false
                queryState.appendMessage(
                    message: "Estimated execution plan generated",
                    severity: .info
                )
            }
        } catch {
            await MainActor.run {
                queryState.isLoadingExecutionPlan = false
                queryState.appendMessage(
                    message: "Failed to generate execution plan: \(error.localizedDescription)",
                    severity: .error
                )
            }
        }
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

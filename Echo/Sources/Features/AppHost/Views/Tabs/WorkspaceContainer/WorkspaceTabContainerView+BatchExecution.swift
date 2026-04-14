import SwiftUI
import EchoSense

extension WorkspaceTabContainerView {

    /// Executes multiple pre-split batches sequentially, collecting per-batch results.
    ///
    /// This is the multi-batch code path used when the user's SQL contains GO separators.
    /// Single-batch queries continue to use the existing `simpleQuery` path.
    func runBatchQuery(
        tabId: UUID,
        batches: [String],
        batchStartLines: [Int],
        queryState: QueryEditorState,
        resolvedSession: DatabaseSession,
        tab: WorkspaceTab,
        trimmedSQL: String
    ) async {
        let foreignKeySource = resolveSchemaAndTable(
            for: inferPrimaryObjectName(from: batches.first ?? ""),
            connection: tab.connection
        )

        let activityHandle = AppDirector.shared.activityEngine.begin("Executing batch query", connectionSessionID: tab.connectionSessionID)
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

                let batchResults = try await resolvedSession.executeBatches(batches) { [weak state] update in
                    guard let state else { return }
                    Task { @MainActor in
                        switch update.event {
                        case .started:
                            state.appendMessage(
                                message: "Batch \(update.batchIndex + 1) of \(update.batchCount) started",
                                severity: .info,
                                category: "Batch"
                            )
                        case .completed:
                            state.appendMessage(
                                message: "Batch \(update.batchIndex + 1) of \(update.batchCount) completed",
                                severity: .info,
                                category: "Batch"
                            )
                        case .failed(let errorMessage):
                            let batchStartLine = update.batchIndex < batchStartLines.count
                                ? batchStartLines[update.batchIndex] : 0
                            state.appendMessage(
                                message: "Batch \(update.batchIndex + 1): \(errorMessage)",
                                severity: .error,
                                category: "Batch",
                                metadata: ["batchStartLine": "\(batchStartLine)"]
                            )
                        case .streamUpdate(let streamUpdate):
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                state.applyStreamUpdate(streamUpdate)
                            }
                        }
                    }
                }

                try Task.checkCancellation()
                await MainActor.run {
                    activityHandle.succeed()
                    consumeBatchResults(batchResults, into: state, batchStartLines: batchStartLines)
                    state.finishExecution()

                    appState.addToQueryHistory(
                        batches.joined(separator: "\nGO\n"),
                        connectionID: tab.connection.id,
                        databaseName: tab.activeDatabaseName ?? tab.connection.database,
                        resultCount: state.results?.rows.count ?? 0,
                        duration: state.lastExecutionTime ?? 0
                    )

                    detectAndApplyDatabaseSwitch(originalSQL: trimmedSQL, tab: tab)

                    if batches.contains(where: { isDDL($0) }),
                       let session = environmentState.sessionGroup.activeSessions
                        .first(where: { $0.id == tab.connectionSessionID }) {
                        Task {
                            await environmentState.refreshDatabaseStructure(for: session.id)
                        }
                    }
                }
            } catch is CancellationError {
                if let dedicatedSession = resolvedSession as? MSSQLDedicatedQuerySession {
                    await MainActor.run { dedicatedSession.reconnectAfterCancellation() }
                }
                await MainActor.run {
                    activityHandle.cancel()
                    state.markCancellationCompleted()
                }
            } catch {
                let shouldTreatAsCancellation = await MainActor.run { state.isCancellationRequested }
                if shouldTreatAsCancellation,
                   let dedicatedSession = resolvedSession as? MSSQLDedicatedQuerySession {
                    await MainActor.run { dedicatedSession.reconnectAfterCancellation() }
                }
                await MainActor.run {
                    if shouldTreatAsCancellation {
                        activityHandle.cancel()
                        state.markCancellationCompleted()
                    } else {
                        activityHandle.fail(error.localizedDescription)
                        state.errorMessage = error.localizedDescription
                        state.failExecution(with: "Batch execution failed: \(error.localizedDescription)")
                    }
                }
            }
        }

        await MainActor.run {
            queryState.errorMessage = nil
            queryState.prefersMessagesAfterExecution = batchResultsPreferMessages(batches, databaseType: tab.connection.databaseType)
            queryState.startExecution()
            queryState.setExecutingTask(task)
            environmentState.dataInspectorContent = nil
        }
    }

    // MARK: - Result Flattening

    /// Converts batch results into the flat result set structure that QueryEditorState expects.
    private func consumeBatchResults(
        _ batchResults: [BatchResult],
        into state: QueryEditorState,
        batchStartLines: [Int]
    ) {
        // Surface all server messages with batch context
        for batchResult in batchResults {
            let batchLabel = batchResults.count > 1 ? "Batch \(batchResult.batchIndex + 1): " : ""
            let batchStartLine = batchResult.batchIndex < batchStartLines.count
                ? batchStartLines[batchResult.batchIndex] : 0

            for message in batchResult.messages {
                let severity: QueryExecutionMessage.Severity = message.kind == .error ? .error : .info
                var metadata: [String: String] = [:]
                if let lineNum = message.lineNumber, lineNum > 0 {
                    metadata["line"] = "\(Int(lineNum) + batchStartLine)"
                }
                state.appendMessage(
                    message: "\(batchLabel)\(message.message)",
                    severity: severity,
                    metadata: metadata
                )
            }

            if let error = batchResult.error {
                state.appendMessage(
                    message: "\(batchLabel)\(error)",
                    severity: .error,
                    category: "Batch"
                )
            }

            // Rows affected summary per batch
            let totalRows = batchResult.resultSets.reduce(0) { $0 + ($1.totalRowCount ?? $1.rows.count) }
            if totalRows > 0 || batchResult.succeeded {
                state.appendMessage(
                    message: "\(batchLabel)Returned \(totalRows) row\(totalRows == 1 ? "" : "s")",
                    severity: .info,
                    metadata: ["rows": "\(totalRows)"]
                )
            }
        }

        // Flatten all result sets from all batches
        var allResultSets: [QueryResultSet] = []
        var batchLabels: [BatchResultLabel] = []

        for batchResult in batchResults {
            for (resultSetIdx, resultSet) in batchResult.resultSets.enumerated() {
                allResultSets.append(resultSet)
                batchLabels.append(BatchResultLabel(
                    batchIndex: batchResult.batchIndex,
                    resultSetIndexInBatch: resultSetIdx
                ))
            }
        }

        if let primary = allResultSets.first {
            let additional = Array(allResultSets.dropFirst())
            state.consumeFinalResult(QueryResultSet(
                columns: primary.columns,
                rows: primary.rows,
                totalRowCount: primary.totalRowCount,
                commandTag: primary.commandTag,
                additionalResults: additional,
                dataClassification: primary.dataClassification,
                serverMessages: primary.serverMessages
            ))
        } else {
            // No result sets from any batch (all were DML/DDL with no output)
            state.consumeFinalResult(QueryResultSet(
                columns: [],
                rows: [],
                totalRowCount: 0
            ))
        }

        // Store batch metadata for UI tab labels
        if batchResults.count > 1 {
            state.batchResultMetadata = batchLabels
        }
    }

    private func batchResultsPreferMessages(_ batches: [String], databaseType: DatabaseType) -> Bool {
        batches.allSatisfy {
            QueryStatementClassifier.isLikelyMessageOnlyStatement($0, databaseType: databaseType)
        }
    }
}

import EchoSense
import Foundation
import OSLog

extension QueryEditorState {
    func startExecution() {
        // An idle drop reconnects on this run (round 21, I1); lost work waits for Reconnect.
        if case .idle = connectionLoss { connectionLoss = nil }
        timeLimitStop = nil
        startLockWaitWatch()
        if rowDiagnosticsEnabled && !hasAnnouncedRowDiagnostics {
            hasAnnouncedRowDiagnostics = true
            Logger.query.debug("RowDiagnostics enabled for query '\(self.sql)'")
        }
        performanceTracker = QueryPerformanceTracker(initialBatchTarget: initialVisibleRowBatch)
        lastPerformanceReport = nil
        livePerformanceReport = nil
        materializedHighWaterMark = 0
        updateForeignKeyResolutionContext(schema: nil, table: nil)
        formattingGeneration &+= 1
        let currentToken = formattingGeneration
        formattingResetTask?.cancel()
        let coordinator = formattingCoordinator
        formattingResetTask = Task(priority: .userInitiated) { [weak self] in
            await coordinator.reset()
            await MainActor.run {
                if let self, self.formattingGeneration == currentToken {
                    self.formattingResetTask = nil
                }
            }
        }
        prepareSpoolForNewExecution()
        didReceiveStreamingUpdate = false
        executionStartTime = Date()
        runStartedAt = executionStartTime
        currentExecutionTime = 0
        lastSpoolStatsRowCount = 0
        hasAppliedFinalSpoolStats = false
        lastBroadcastSnapshot = nil
        isExecuting = true
        executionGeneration &+= 1
        wasCancelled = false
        isCancellationRequested = false
        visibleRowLimit = initialVisibleRowBatch

        if isResultsOnly, var preview = dataPreviewState {
            preview.isFetching = true; preview.nextOffset = 0; preview.hasMoreData = true
            dataPreviewState = preview
            dataPreviewFetchTask?.cancel(); dataPreviewFetchTask = nil
        }

        let isFirstExecution = !hasExecutedAtLeastOnce
        hasExecutedAtLeastOnce = true
        if isFirstExecution { splitRatio = 0.5 }
        lastMessageTimestamp = nil
        executingTask?.cancel(); executingTask = nil

        messages.removeAll()
        messageStatement = lastRunRange.flatMap { QueryMessageStatement.heading(for: sql, range: $0) }
        runNote = nil
        errorMark = nil
        messageLineMapper = nil
        streamingColumns.removeAll(keepingCapacity: false)
        streamingRows.removeAll(keepingCapacity: false)
        rowProgress = RowProgress()
        streamingMode = .preview
        results = nil
        additionalResults.removeAll()
        streamedAdditionalStates.removeAll()
        selectedResultSetIndex = 0
        batchResultMetadata = nil
        scriptEntries = nil
        selectedScriptEntryID = nil
        highlightedStatementRange = nil
        dataClassification = nil
        markResultDataChanged()

        // Round 41.4, EM0: Messages holds what the server said; Echo's own "started", "finished"
        // and "failed" lines are gone (the footer's status says it).

        executionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let startTime = self.executionStartTime else { return }
                let elapsed = floor(Date().timeIntervalSince(startTime))
                if Int(elapsed) != Int(self.currentExecutionTime) { self.currentExecutionTime = elapsed }
            }
        }
    }

    func recordQueryDispatched() { performanceTracker.markQueryDispatched() }

    func finishExecution() {
        if let startTime = executionStartTime { lastExecutionTime = Date().timeIntervalSince(startTime) }
        isExecuting = false; wasCancelled = false; isCancellationRequested = false; executingTask = nil
        cancelPhase = nil; forceStopHandler = nil
        stopLockWaitWatch()
        refreshTransactionState()
        executionTimer?.invalidate(); executionTimer = nil
        streamingMode = .completed
        let endTime = Date()
        recordRun(startedAt: executionStartTime, finishedAt: endTime, outcome: .succeeded)
        executionStartTime = nil
        visibleRowLimit = isResultsOnly ? initialVisibleRowBatch : nil

        if isResultsOnly, var preview = dataPreviewState {
            let total = totalAvailableRowCount
            preview.nextOffset = total; preview.hasMoreData = total >= preview.batchSize; preview.isFetching = false
            dataPreviewState = preview
        }
        let finalMat = max(rowProgress.materialized, totalAvailableRowCount)
        rowProgress = RowProgress(materialized: finalMat, reported: max(rowProgress.reported, finalMat), received: max(streamedRowCount, finalMat))
        materializedHighWaterMark = max(materializedHighWaterMark, finalMat)

        finalizeSpoolOnCompletion(cancelled: false)
        finalizePerformanceMetrics(cancelled: false)
        // The footer's count: every row the server sent, not only those already read back from the spool.
        runNote = QueryRunNote.success(range: lastRunRange, rows: rowProgress.displayCount, hasResults: results != nil || !streamingColumns.isEmpty, duration: lastExecutionTime)
        runEndedHandler?(true)
    }

    func failExecution(with error: String) {
        isExecuting = false; wasCancelled = false; isCancellationRequested = false; executingTask = nil
        cancelPhase = nil; forceStopHandler = nil
        stopLockWaitWatch()
        noteTimeLimitStopIfNeeded(error)
        refreshTransactionState()
        executionTimer?.invalidate(); executionTimer = nil
        let endTime = Date()
        if let startTime = executionStartTime { lastExecutionTime = endTime.timeIntervalSince(startTime) }
        // The error itself, when the server's messages didn't carry it (Echo's own "failed" line is gone, EM0).
        if !messages.contains(where: { $0.severity == .error }) {
            appendMessage(message: errorMessage ?? error, severity: .error, category: "Server Response", timestamp: endTime)
        }
        recordRun(startedAt: executionStartTime, finishedAt: endTime, outcome: .failed)
        executionStartTime = nil; shouldPersistResults = false
        finalizeSpoolOnCompletion(cancelled: false)
        streamingColumns.removeAll(); streamingRows.removeAll(); results = nil
        visibleRowLimit = isResultsOnly ? initialVisibleRowBatch : nil
        if isResultsOnly, var preview = dataPreviewState { preview.isFetching = false; dataPreviewState = preview }
        dataPreviewFetchTask?.cancel(); dataPreviewFetchTask = nil
        rowProgress = RowProgress(); materializedHighWaterMark = 0
        markResultDataChanged()
        finalizePerformanceMetrics(cancelled: true)
        runNote = QueryRunNote.failure(range: lastRunRange, message: error)
        runEndedHandler?(false)
    }

    func setExecutingTask(_ task: Task<Void, Never>) {
        executingTask?.cancel()
        executingTask = task
    }

    func cancelExecution() {
        isCancellationRequested = true
        if let task = executingTask { task.cancel() }
        else if isExecuting { markCancellationCompleted() }
    }

    func markCancellationCompleted() {
        executingTask = nil; isExecuting = false; isCancellationRequested = false; executionTimer?.invalidate(); executionTimer = nil
        cancelPhase = nil; forceStopHandler = nil
        stopLockWaitWatch()
        refreshTransactionState()
        streamingMode = .completed
        let endTime = Date()
        if let startTime = executionStartTime { lastExecutionTime = endTime.timeIntervalSince(startTime) }
        wasCancelled = true; errorMessage = nil
        if !streamingRows.isEmpty {
            let snapshot = QueryResultSet(columns: streamingColumns, rows: streamingRows)
            results = snapshot
            let count = streamingRows.count
            rowProgress = RowProgress(materialized: count, reported: max(rowProgress.reported, count), received: max(streamedRowCount, count))
            visibleRowLimit = count; materializedHighWaterMark = count
        }
        // Round 21, cancel CR2 (and round 22 CL1 for SQL Server): the run note and Messages.
        let cancelledRows = streamingRows.isEmpty ? (results?.rows.count ?? 0) : streamingRows.count
        appendMessage(message: QueryRunNote.cancelledText(duration: lastExecutionTime, rows: cancelledRows), severity: .warning, timestamp: endTime, duration: executionStartTime.map { endTime.timeIntervalSince($0) })
        runNote = QueryRunNote.cancelled(range: lastRunRange, duration: lastExecutionTime, rows: cancelledRows)
        recordRun(startedAt: executionStartTime, finishedAt: endTime, outcome: .cancelled)
        executionStartTime = nil; streamingColumns.removeAll(); streamingRows.removeAll()
        if results == nil { visibleRowLimit = nil; materializedHighWaterMark = 0; rowProgress = RowProgress() }
        if isResultsOnly, var preview = dataPreviewState { preview.isFetching = false; dataPreviewState = preview }
        dataPreviewFetchTask?.cancel(); dataPreviewFetchTask = nil
        markResultDataChanged(); shouldPersistResults = false
        finalizeSpoolOnCompletion(cancelled: true)
        finalizePerformanceMetrics(cancelled: false)
    }
}

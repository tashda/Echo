import Foundation
import OSLog

extension QueryEditorState {
    func startExecution() {
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
        streamingColumns.removeAll(keepingCapacity: false)
        streamingRows.removeAll(keepingCapacity: false)
        rowProgress = RowProgress()
        streamingMode = .preview
        results = nil
        additionalResults.removeAll()
        selectedResultSetIndex = 0
        batchResultMetadata = nil
        dataClassification = nil
        markResultDataChanged()

        appendMessage(message: "Query execution started", severity: .info, timestamp: executionStartTime ?? Date(), duration: nil)

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
        executionTimer?.invalidate(); executionTimer = nil
        streamingMode = .completed
        let endTime = Date()
        if let startTime = executionStartTime {
            appendMessage(message: "Query execution finished", severity: .success, timestamp: endTime, duration: endTime.timeIntervalSince(startTime))
        }
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
    }

    func failExecution(with error: String) {
        isExecuting = false; wasCancelled = false; isCancellationRequested = false; executingTask = nil
        executionTimer?.invalidate(); executionTimer = nil
        let endTime = Date()
        if let startTime = executionStartTime { lastExecutionTime = endTime.timeIntervalSince(startTime) }
        appendMessage(message: "Query execution failed", severity: .error, timestamp: endTime, duration: executionStartTime.map { endTime.timeIntervalSince($0) }, metadata: ["error": error])
        executionStartTime = nil; shouldPersistResults = false
        finalizeSpoolOnCompletion(cancelled: false)
        streamingColumns.removeAll(); streamingRows.removeAll(); results = nil
        visibleRowLimit = isResultsOnly ? initialVisibleRowBatch : nil
        if isResultsOnly, var preview = dataPreviewState { preview.isFetching = false; dataPreviewState = preview }
        dataPreviewFetchTask?.cancel(); dataPreviewFetchTask = nil
        rowProgress = RowProgress(); materializedHighWaterMark = 0
        markResultDataChanged()
        finalizePerformanceMetrics(cancelled: true)
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
        appendMessage(message: "Query execution canceled", severity: .warning, timestamp: endTime, duration: executionStartTime.map { endTime.timeIntervalSince($0) })
        executionStartTime = nil; streamingColumns.removeAll(); streamingRows.removeAll()
        if results == nil { visibleRowLimit = nil; materializedHighWaterMark = 0; rowProgress = RowProgress() }
        if isResultsOnly, var preview = dataPreviewState { preview.isFetching = false; dataPreviewState = preview }
        dataPreviewFetchTask?.cancel(); dataPreviewFetchTask = nil
        markResultDataChanged(); shouldPersistResults = false
        finalizeSpoolOnCompletion(cancelled: true)
        finalizePerformanceMetrics(cancelled: false)
    }
}

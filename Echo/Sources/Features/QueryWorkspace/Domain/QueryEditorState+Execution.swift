import Foundation
import os.log
import os.signpost

extension QueryEditorState {
    func startExecution() {
        if rowDiagnosticsEnabled && !hasAnnouncedRowDiagnostics {
            hasAnnouncedRowDiagnostics = true
            print("[RowDiagnostics] Enabled for query '\(sql)'")
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
        wasCancelled = false
        visibleRowLimit = initialVisibleRowBatch

        if isResultsOnly, var preview = dataPreviewState {
            preview.isFetching = true
            preview.nextOffset = 0
            preview.hasMoreData = true
            dataPreviewState = preview
            dataPreviewFetchTask?.cancel()
            dataPreviewFetchTask = nil
        }

        let isFirstExecution = !hasExecutedAtLeastOnce
        hasExecutedAtLeastOnce = true
        if isFirstExecution {
            splitRatio = 0.5
        }
        lastMessageTimestamp = nil

        executingTask?.cancel()
        executingTask = nil

        messages.removeAll()
        streamingColumns.removeAll(keepingCapacity: false)
        streamingRows.removeAll(keepingCapacity: false)
        rowProgress = RowProgress()
        streamingMode = .preview
        results = nil
        markResultDataChanged()

        let timestamp = executionStartTime ?? Date()
        appendMessage(
            message: "Query execution started",
            severity: .info,
            timestamp: timestamp,
            duration: nil
        )

        executionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let startTime = self.executionStartTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let rounded = floor(elapsed)
                if Int(rounded) != Int(self.currentExecutionTime) {
                    self.currentExecutionTime = rounded
                }
            }
        }
    }

    func recordQueryDispatched() {
        performanceTracker.markQueryDispatched()
    }

    func finishExecution() {
        if let startTime = executionStartTime {
            lastExecutionTime = Date().timeIntervalSince(startTime)
        }
        isExecuting = false
        wasCancelled = false
        executingTask = nil
        executionTimer?.invalidate()
        executionTimer = nil
        streamingMode = .completed
        let endTime = Date()
        if let startTime = executionStartTime {
            appendMessage(
                message: "Query execution finished",
                severity: .success,
                timestamp: endTime,
                duration: endTime.timeIntervalSince(startTime)
            )
        }
        executionStartTime = nil
        if isResultsOnly {
            visibleRowLimit = initialVisibleRowBatch
        } else {
            visibleRowLimit = nil
        }

        if isResultsOnly, var preview = dataPreviewState {
            let total = totalAvailableRowCount
            preview.nextOffset = total
            preview.hasMoreData = total >= preview.batchSize
            preview.isFetching = false
            dataPreviewState = preview
        }
        let finalMaterialized = max(rowProgress.materialized, totalAvailableRowCount)
        let finalReported = max(rowProgress.reported, finalMaterialized)
        rowProgress = RowProgress(
            materialized: finalMaterialized,
            reported: finalReported,
            received: max(streamedRowCount, finalMaterialized)
        )
        materializedHighWaterMark = max(materializedHighWaterMark, finalMaterialized)

        finalizeSpoolOnCompletion(cancelled: false)
        finalizePerformanceMetrics(cancelled: false)
    }

    func failExecution(with error: String) {
        isExecuting = false
        wasCancelled = false
        executingTask = nil
        executionTimer?.invalidate()
        executionTimer = nil
        let endTime = Date()
        if let startTime = executionStartTime {
            lastExecutionTime = endTime.timeIntervalSince(startTime)
        }
        appendMessage(
            message: "Query execution failed",
            severity: .error,
            timestamp: endTime,
            duration: executionStartTime.map { endTime.timeIntervalSince($0) },
            metadata: ["error": error]
        )
        executionStartTime = nil
        shouldPersistResults = false
        finalizeSpoolOnCompletion(cancelled: false)
        streamingColumns.removeAll(keepingCapacity: false)
        streamingRows.removeAll(keepingCapacity: false)
        results = nil
        if isResultsOnly {
            visibleRowLimit = initialVisibleRowBatch
        } else {
            visibleRowLimit = nil
        }
        if isResultsOnly, var preview = dataPreviewState {
            preview.isFetching = false
            dataPreviewState = preview
        }
        dataPreviewFetchTask?.cancel()
        dataPreviewFetchTask = nil
        rowProgress = RowProgress()
        materializedHighWaterMark = 0
        markResultDataChanged()

        finalizePerformanceMetrics(cancelled: true)
    }

    func appendMessage(
        message: String,
        severity: QueryExecutionMessage.Severity,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        procedure: String? = nil,
        line: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        let index = messages.count + 1
        let delta: TimeInterval
        if let lastTimestamp = lastMessageTimestamp {
            delta = timestamp.timeIntervalSince(lastTimestamp)
        } else {
            delta = 0
        }

        let entry = QueryExecutionMessage(
            index: index,
            message: message,
            timestamp: timestamp,
            severity: severity,
            delta: delta,
            duration: duration,
            procedure: procedure,
            line: line,
            metadata: metadata
        )
        messages.append(entry)
        lastMessageTimestamp = timestamp
    }

    func setExecutingTask(_ task: Task<Void, Never>) {
        executingTask?.cancel()
        executingTask = task
    }

    func cancelExecution() {
        if let task = executingTask {
            task.cancel()
        } else if isExecuting {
            markCancellationCompleted()
        }
    }

    func markCancellationCompleted() {
        executingTask = nil
        isExecuting = false
        executionTimer?.invalidate()
        executionTimer = nil
        streamingMode = .completed

        let endTime = Date()
        if let startTime = executionStartTime {
            lastExecutionTime = endTime.timeIntervalSince(startTime)
        }

        wasCancelled = true
        errorMessage = nil
        if !streamingRows.isEmpty {
            let snapshot = QueryResultSet(columns: streamingColumns, rows: streamingRows)
            results = snapshot
            let retainedCount = streamingRows.count
            let updatedReported = max(rowProgress.reported, retainedCount)
            rowProgress = RowProgress(
                materialized: retainedCount,
                reported: updatedReported,
                received: max(streamedRowCount, retainedCount)
            )
            visibleRowLimit = retainedCount
            materializedHighWaterMark = retainedCount
        }
        appendMessage(
            message: "Query execution canceled",
            severity: .warning,
            timestamp: endTime,
            duration: executionStartTime.map { endTime.timeIntervalSince($0) }
        )

        executionStartTime = nil
        streamingColumns.removeAll(keepingCapacity: false)
        streamingRows.removeAll(keepingCapacity: false)
        if results == nil {
            visibleRowLimit = nil
            materializedHighWaterMark = 0
            rowProgress = RowProgress()
        }
        if isResultsOnly, var preview = dataPreviewState {
            preview.isFetching = false
            dataPreviewState = preview
        }
        dataPreviewFetchTask?.cancel()
        dataPreviewFetchTask = nil
        markResultDataChanged()

        shouldPersistResults = false
        finalizeSpoolOnCompletion(cancelled: true)
        finalizePerformanceMetrics(cancelled: false)
    }

    @MainActor
    func applyStreamUpdate(_ update: QueryStreamUpdate) {
        guard !update.columns.isEmpty else { return }

        if streamingMode == .idle {
            streamingMode = .preview
        }

        let modeForSpool = streamingMode
        let columnsWereEmpty = streamingColumns.isEmpty
        if columnsWereEmpty {
            streamingColumns = update.columns
        }

        let rawRows = update.rawRows
        let appendedRange = update.rowRange

        let appendedRowCount: Int = {
            if let range = appendedRange {
                return range.count
            }
            if !rawRows.isEmpty {
                return rawRows.count
            }
            if !update.appendedRows.isEmpty {
                return update.appendedRows.count
            }
            if !update.encodedRows.isEmpty {
                return update.encodedRows.count
            }
            return 0
        }()

        let gridPipelineLog = OSLog(subsystem: "dk.tippr.echo", category: .pointsOfInterest)
        os_log("ApplyStreamUpdate begin rows=%{public}d", log: gridPipelineLog, type: .info, appendedRowCount)
        print("[Signpost] ApplyStreamUpdate begin rows=\(appendedRowCount)")
        if #available(macOS 10.14, *) {
            os_signpost(.begin, log: gridPipelineLog, name: "ApplyStreamUpdate", "%{public}d rows", appendedRowCount)
        }
        defer {
            os_log("ApplyStreamUpdate end", log: gridPipelineLog, type: .info)
            print("[Signpost] ApplyStreamUpdate end")
            if #available(macOS 10.14, *) {
                os_signpost(.end, log: gridPipelineLog, name: "ApplyStreamUpdate")
            }
        }

        if appendedRowCount > 0 {
            let previousStreamed = streamedRowCount
            let provisionalStreamed = previousStreamed &+ appendedRowCount
            let knownTotals = [
                update.totalRowCount,
                rowProgress.totalReported,
                rowProgress.totalReceived,
                materializedHighWaterMark,
                results?.totalRowCount ?? 0
            ].filter { $0 > 0 }
            let upperBound = knownTotals.max() ?? provisionalStreamed
            if rowDiagnosticsEnabled, provisionalStreamed > upperBound {
                debugReportRowAnomaly(
                    stage: "applyStreamUpdate",
                    message: "clamping streamedRowCount provisional=\(provisionalStreamed) upperBound=\(upperBound) totals=\(knownTotals)"
                )
            }
            streamedRowCount = min(provisionalStreamed, upperBound)
            debugTrackRowCountChange(
                event: "applyStreamUpdate",
                previous: previousStreamed,
                current: streamedRowCount,
                details: "appended=\(appendedRowCount) total=\(update.totalRowCount) rowRange=\(appendedRange.map { "\($0.lowerBound)..<\($0.upperBound)" } ?? "nil") raw=\(rawRows.count) encoded=\(update.encodedRows.count)"
            )
            didReceiveStreamingUpdate = true

            let updatedProgress = RowProgress(
                totalReceived: max(streamedRowCount, rowProgress.totalReceived),
                totalReported: rowProgress.totalReported,
                materialized: rowProgress.materialized
            )
            if updatedProgress != rowProgress {
                rowProgress = updatedProgress
            }
        }
        else {
            // Progress-only update: advance reported total without integrating rows
            let newReported = max(rowProgress.totalReported, update.totalRowCount)
            if newReported != rowProgress.totalReported {
                rowProgress = RowProgress(
                    totalReceived: rowProgress.totalReceived,
                    totalReported: newReported,
                    materialized: rowProgress.materialized
                )
                markResultDataChanged()
                if streamingMode == .preview || isExecuting {
                    refreshLivePerformanceReport()
                }
            }
        }

        let estimatedTotal = max(update.totalRowCount, streamedRowCount)
        if appendedRowCount > 0 {
            performanceTracker.recordStreamUpdate(appendedRowCount: appendedRowCount, totalRowCount: estimatedTotal)
        }
        if estimatedTotal >= initialVisibleRowBatch {
            performanceTracker.recordInitialBatchReady(totalRowCount: estimatedTotal)
        }
        if let metrics = update.metrics {
            performanceTracker.recordBackendMetrics(metrics)
        }

        let nextStreamedCount = streamedRowCount + appendedRowCount
        if streamingMode == .preview,
           nextStreamedCount >= spoolActivationThreshold {
            streamingMode = .background
            if !isResultsOnly, visibleRowLimit != nil {
                visibleRowLimit = nil
            }
            shouldPersistResults = true
        }

        let effectiveShouldPersist = shouldPersistResults || streamingMode == .background
        let bufferLimit = effectiveShouldPersist ? frontBufferLimit : max(frontBufferLimit, estimatedTotal)
        let remainingBufferCapacity = max(bufferLimit - streamingRows.count, 0)
        if effectiveShouldPersist,
           appendedRowCount > 0,
           remainingBufferCapacity <= 0 {
            let spoolEncodedRows: [ResultBinaryRow]
            let spoolRawRows: [ResultRowPayload]
            let spoolFormattedRows: [[String?]]
            if !update.encodedRows.isEmpty {
                spoolEncodedRows = update.encodedRows
                spoolRawRows = []
                spoolFormattedRows = []
            } else if !update.rawRows.isEmpty {
                spoolEncodedRows = []
                spoolRawRows = update.rawRows
                spoolFormattedRows = []
            } else {
                spoolEncodedRows = []
                spoolRawRows = []
                spoolFormattedRows = update.appendedRows
            }
            let spoolPayload = QueryStreamUpdate(
                columns: update.columns,
                appendedRows: spoolFormattedRows,
                encodedRows: spoolEncodedRows,
                rawRows: spoolRawRows,
                totalRowCount: update.totalRowCount,
                metrics: update.metrics,
                rowRange: update.rowRange
            )
            submitToSpool(update: spoolPayload, mode: modeForSpool)
            let resolvedTotal = estimatedTotal > 0 ? estimatedTotal : rowProgress.totalReported
            if resolvedTotal > 0, streamedRowCount > resolvedTotal {
                streamedRowCount = resolvedTotal
            }
            let receivedSource = max(streamedRowCount, rowProgress.totalReceived)
            let newReported = resolvedTotal
            let newReceived = resolvedTotal > 0 ? min(receivedSource, resolvedTotal) : receivedSource
            let newMaterialized = resolvedTotal > 0 ? min(rowProgress.materialized, resolvedTotal) : rowProgress.materialized
            if rowProgress.totalReported != newReported
                || rowProgress.totalReceived != newReceived
                || rowProgress.materialized != newMaterialized {
                rowProgress = RowProgress(
                    totalReceived: newReceived,
                    totalReported: newReported,
                    materialized: newMaterialized
                )
            }
            markResultDataChanged()
            if streamingMode == .preview || isExecuting {
                refreshLivePerformanceReport()
            }
            activateSpoolIfNeeded()
            return
        }

        let columnsForBatch = streamingColumns.isEmpty ? update.columns : streamingColumns
        let treatAsPreview = !effectiveShouldPersist && (modeForSpool == .preview || modeForSpool == .idle)
        let shouldDefer = resultsTypeFormattingEnabled && !rawRows.isEmpty && (resultsFormattingMode == .deferred || streamingMode != .preview)
        var spoolPreviewRows: [[String?]] = []

        if !shouldDefer {
            let rangeLower = appendedRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
            let previewCap = max(frontBufferLimit, previewRowLimit)
            let displayCap = effectiveShouldPersist ? bufferLimit : previewCap
            let maxDisplayIndex = min(rangeLower + appendedRowCount, displayCap)
            let displayCount = max(0, min(appendedRowCount, maxDisplayIndex - rangeLower))
            let formattedRows: [[String?]]
            if !update.appendedRows.isEmpty {
                if effectiveShouldPersist && displayCount == 0 {
                    formattedRows = []
                } else if !effectiveShouldPersist || displayCount >= update.appendedRows.count {
                    formattedRows = update.appendedRows
                } else {
                    formattedRows = Array(update.appendedRows.prefix(displayCount))
                }
            } else if !rawRows.isEmpty {
                if effectiveShouldPersist {
                    let payloadsToFormat = Array(rawRows.prefix(displayCount))
                    formattedRows = formatRowsSynchronously(payloadsToFormat)
                } else {
                    formattedRows = formatRowsSynchronously(rawRows)
                }
            } else {
                formattedRows = []
            }

            if !formattedRows.isEmpty {
                let startIndex = rangeLower
                let resolvedRange = startIndex..<(startIndex + formattedRows.count)
                integrateFormattedRows(
                    rows: formattedRows,
                    range: resolvedRange,
                    totalRowCount: estimatedTotal,
                    metrics: update.metrics,
                    treatAsPreview: treatAsPreview,
                    columns: columnsForBatch
                )
                if treatAsPreview {
                    spoolPreviewRows = formattedRows
                }
            }
        } else {
            let rangeLower = appendedRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
            let previewCap = max(frontBufferLimit, previewRowLimit)
            let displayCap = effectiveShouldPersist ? bufferLimit : previewCap
            let maxDisplayIndex = min(rangeLower + appendedRowCount, displayCap)
            var immediateCount = 0
            var integratedRowsForSpool: [[String?]] = []
            if let range = appendedRange, !update.appendedRows.isEmpty {
                let displayCount = max(0, min(update.appendedRows.count, maxDisplayIndex - rangeLower))
                immediateCount = displayCount
                if displayCount > 0 {
                    let rowsToIntegrate = displayCount < update.appendedRows.count
                        ? Array(update.appendedRows.prefix(displayCount))
                        : update.appendedRows
                    integratedRowsForSpool = rowsToIntegrate
                    let immediateRange = range.lowerBound..<(range.lowerBound + rowsToIntegrate.count)
                    integrateFormattedRows(
                        rows: rowsToIntegrate,
                        range: immediateRange,
                        totalRowCount: estimatedTotal,
                        metrics: update.metrics,
                        treatAsPreview: treatAsPreview,
                        columns: columnsForBatch
                    )
                }
            } else if !rawRows.isEmpty {
                let previewRemaining = max(previewRowLimit - rowProgress.materialized, 0)
                let displayBudget = max(0, maxDisplayIndex - rangeLower)
                immediateCount = min(previewRemaining, min(rawRows.count, displayBudget))
                if immediateCount > 0 {
                    let startIndex = appendedRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
                    let immediatePayloads = Array(rawRows.prefix(immediateCount))
                    let immediateRows = formatRowsSynchronously(immediatePayloads)
                    let immediateRange = startIndex..<(startIndex + immediateCount)
                    integratedRowsForSpool = immediateRows
                    integrateFormattedRows(
                        rows: immediateRows,
                        range: immediateRange,
                        totalRowCount: estimatedTotal,
                        metrics: update.metrics,
                        treatAsPreview: true,
                        columns: columnsForBatch
                    )
                }
            }

            if rawRows.count > immediateCount {
                let startIndex = appendedRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
                let deferredStart = startIndex + immediateCount
                let deferredRows = Array(rawRows.dropFirst(immediateCount))
                let deferredRange = deferredStart..<(deferredStart + deferredRows.count)
                enqueueDeferredBatch(
                    rows: deferredRows,
                    range: deferredRange,
                    totalRowCount: estimatedTotal,
                    metrics: update.metrics,
                    treatAsPreview: false,
                    columns: columnsForBatch
                )
            }
            if treatAsPreview {
                spoolPreviewRows = integratedRowsForSpool
            }
        }

        let spoolEncodedRows: [ResultBinaryRow]
        let spoolRawRows: [ResultRowPayload]
        let fallbackAppendedRows: [[String?]]
        if !update.encodedRows.isEmpty {
            spoolEncodedRows = update.encodedRows
            spoolRawRows = []
            fallbackAppendedRows = []
        } else if !update.rawRows.isEmpty {
            spoolEncodedRows = []
            spoolRawRows = update.rawRows
            fallbackAppendedRows = []
        } else {
            spoolEncodedRows = []
            spoolRawRows = []
            fallbackAppendedRows = update.appendedRows
        }
        let appendedRowsForSpool: [[String?]]
        if treatAsPreview {
            appendedRowsForSpool = !spoolPreviewRows.isEmpty ? spoolPreviewRows : []
        } else {
            appendedRowsForSpool = fallbackAppendedRows
        }

        let spoolPayload = QueryStreamUpdate(
            columns: update.columns,
            appendedRows: appendedRowsForSpool,
            encodedRows: spoolEncodedRows,
            rawRows: spoolRawRows,
            totalRowCount: update.totalRowCount,
            metrics: update.metrics,
            rowRange: update.rowRange
        )
        submitToSpool(update: spoolPayload, mode: modeForSpool)

        if appendedRowCount > 0 && spoolPreviewRows.isEmpty {
            let resolvedTotal = estimatedTotal > 0 ? estimatedTotal : rowProgress.totalReported
            if resolvedTotal > 0, streamedRowCount > resolvedTotal {
                streamedRowCount = resolvedTotal
            }
            let receivedSource = max(streamedRowCount, rowProgress.totalReceived)
            let newReported = resolvedTotal
            let newReceived = resolvedTotal > 0 ? min(receivedSource, resolvedTotal) : receivedSource
            let newMaterialized = resolvedTotal > 0 ? min(rowProgress.materialized, resolvedTotal) : rowProgress.materialized
            if rowProgress.totalReported != newReported
                || rowProgress.totalReceived != newReceived
                || rowProgress.materialized != newMaterialized {
                rowProgress = RowProgress(
                    totalReceived: newReceived,
                    totalReported: newReported,
                    materialized: newMaterialized
                )
            }
            markResultDataChanged()
        }

        if streamingMode == .preview,
           streamedRowCount >= spoolActivationThreshold {
            streamingMode = .background
            if !isResultsOnly, visibleRowLimit != nil {
                visibleRowLimit = nil
            }
            shouldPersistResults = true
        }

        if columnsWereEmpty {
            markResultDataChanged()
        }

        if streamingMode == .preview || isExecuting {
            refreshLivePerformanceReport()
        }

        activateSpoolIfNeeded()
    }

    func consumeFinalResult(_ result: QueryResultSet) {
        let totalRowCount = result.totalRowCount ?? result.rows.count
        performanceTracker.markResultSetReceived(totalRowCount: totalRowCount)
        streamingMode = .completed
        streamingColumns = result.columns
        shouldPersistResults = shouldPersistResults || totalRowCount >= spoolActivationThreshold

        let bufferLimit = shouldPersistResults ? frontBufferLimit : max(frontBufferLimit, totalRowCount)
        let truncatedRows = Array(result.rows.prefix(bufferLimit))
        rowCache.ingest(rows: truncatedRows, startingAt: 0)
        let previousStreamed = streamedRowCount
        let resolvedStreamed = max(streamedRowCount, totalRowCount)
        debugTrackRowCountChange(
            event: "consumeFinalResult",
            previous: previousStreamed,
            current: resolvedStreamed,
            details: "resultTotal=\(totalRowCount) truncated=\(truncatedRows.count)"
        )
        streamedRowCount = resolvedStreamed

        if streamingRows.isEmpty || streamingRows.count < truncatedRows.count {
            streamingRows = truncatedRows
        } else {
            for index in 0..<truncatedRows.count {
                streamingRows[index] = truncatedRows[index]
            }
        }

        let condensedResult = QueryResultSet(
            columns: result.columns,
            rows: truncatedRows,
            totalRowCount: totalRowCount,
            commandTag: result.commandTag
        )
        results = condensedResult

        let updatedMaterialized = max(rowProgress.materialized, truncatedRows.count)
        let updatedReported = max(rowProgress.reported, totalRowCount)
        rowProgress = RowProgress(
            materialized: updatedMaterialized,
            reported: updatedReported,
            received: streamedRowCount
        )
        materializedHighWaterMark = max(materializedHighWaterMark, updatedMaterialized)

        if isResultsOnly {
            visibleRowLimit = min(initialVisibleRowBatch, totalRowCount)
        } else {
            visibleRowLimit = nil
        }
        refreshMaterializedProgress()
        markResultDataChanged()
        refreshLivePerformanceReport()
        if shouldPersistResults {
            activateSpoolIfNeeded()
            finalizeSpool(with: result)
        } else {
            shouldPersistResults = false
            deferredSpoolUpdates.removeAll(keepingCapacity: false)
            ingestionService = nil
            spoolHandle = nil
            resultSpoolID = nil
            spoolStatsTask?.cancel()
            spoolStatsTask = nil
        }
    }
}

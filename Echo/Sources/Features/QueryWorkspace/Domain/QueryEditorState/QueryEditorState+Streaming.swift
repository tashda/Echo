import Foundation
import os.log
import os.signpost

extension QueryEditorState {
    @MainActor
    func applyStreamUpdate(_ update: QueryStreamUpdate) {
        guard !update.columns.isEmpty else { return }
        if streamingMode == .idle { streamingMode = .preview }
        let modeForSpool = streamingMode
        if streamingColumns.isEmpty { streamingColumns = update.columns }

        let appendedRowCount = update.rowRange?.count ?? (!update.rawRows.isEmpty ? update.rawRows.count : (!update.appendedRows.isEmpty ? update.appendedRows.count : (!update.encodedRows.isEmpty ? update.encodedRows.count : 0)))

        if appendedRowCount > 0 {
            let previous = streamedRowCount
            let provisional = previous &+ appendedRowCount
            let upperBound = [update.totalRowCount, rowProgress.totalReported, rowProgress.totalReceived, materializedHighWaterMark, results?.totalRowCount ?? 0].filter { $0 > 0 }.max() ?? provisional
            streamedRowCount = min(provisional, upperBound)
            didReceiveStreamingUpdate = true
            rowProgress = RowProgress(totalReceived: max(streamedRowCount, rowProgress.totalReceived), totalReported: rowProgress.totalReported, materialized: rowProgress.materialized)
        } else {
            let newReported = max(rowProgress.totalReported, update.totalRowCount)
            if newReported != rowProgress.totalReported {
                rowProgress = RowProgress(totalReceived: rowProgress.totalReceived, totalReported: newReported, materialized: rowProgress.materialized)
                markResultDataChanged()
                if streamingMode == .preview || isExecuting { refreshLivePerformanceReport() }
            }
        }

        let estimatedTotal = max(update.totalRowCount, streamedRowCount)
        if appendedRowCount > 0 { performanceTracker.recordStreamUpdate(appendedRowCount: appendedRowCount, totalRowCount: estimatedTotal) }
        if estimatedTotal >= initialVisibleRowBatch { performanceTracker.recordInitialBatchReady(totalRowCount: estimatedTotal) }
        if let metrics = update.metrics { performanceTracker.recordBackendMetrics(metrics) }

        if streamingMode == .preview, (streamedRowCount + appendedRowCount) >= spoolActivationThreshold {
            streamingMode = .background
            if !isResultsOnly { visibleRowLimit = nil }
            shouldPersistResults = true
        }

        let effectiveShouldPersist = shouldPersistResults || streamingMode == .background
        let bufferLimit = effectiveShouldPersist ? frontBufferLimit : max(frontBufferLimit, estimatedTotal)
        
        if effectiveShouldPersist, appendedRowCount > 0, max(bufferLimit - streamingRows.count, 0) <= 0 {
            let spoolPayload = QueryStreamUpdate(
                columns: update.columns,
                appendedRows: update.encodedRows.isEmpty && update.rawRows.isEmpty ? update.appendedRows : [],
                encodedRows: update.encodedRows,
                rawRows: update.rawRows,
                totalRowCount: update.totalRowCount,
                metrics: update.metrics,
                rowRange: update.rowRange
            )
            submitToSpool(update: spoolPayload, mode: modeForSpool)
            let resolvedTotal = estimatedTotal > 0 ? estimatedTotal : rowProgress.totalReported
            if resolvedTotal > 0, streamedRowCount > resolvedTotal { streamedRowCount = resolvedTotal }
            rowProgress = RowProgress(totalReceived: resolvedTotal > 0 ? min(max(streamedRowCount, rowProgress.totalReceived), resolvedTotal) : max(streamedRowCount, rowProgress.totalReceived), totalReported: resolvedTotal, materialized: resolvedTotal > 0 ? min(rowProgress.materialized, resolvedTotal) : rowProgress.materialized)
            markResultDataChanged()
            if streamingMode == .preview || isExecuting { refreshLivePerformanceReport() }
            activateSpoolIfNeeded()
            return
        }

        let treatAsPreview = !effectiveShouldPersist && (modeForSpool == .preview || modeForSpool == .idle)
        let shouldDefer = resultsTypeFormattingEnabled && !update.rawRows.isEmpty && (resultsFormattingMode == .deferred || streamingMode != .preview)
        var spoolPreviewRows: [[String?]] = []

        if !shouldDefer {
            let rangeLower = update.rowRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
            let displayCap = effectiveShouldPersist ? bufferLimit : max(frontBufferLimit, previewRowLimit)
            let displayCount = max(0, min(appendedRowCount, min(rangeLower + appendedRowCount, displayCap) - rangeLower))
            let formattedRows: [[String?]]
            if !update.appendedRows.isEmpty {
                formattedRows = (effectiveShouldPersist && displayCount == 0) ? [] : (effectiveShouldPersist && displayCount < update.appendedRows.count ? Array(update.appendedRows.prefix(displayCount)) : update.appendedRows)
            } else if !update.rawRows.isEmpty {
                formattedRows = formatRowsSynchronously(effectiveShouldPersist ? Array(update.rawRows.prefix(displayCount)) : update.rawRows)
            } else { formattedRows = [] }

            if !formattedRows.isEmpty {
                integrateFormattedRows(rows: formattedRows, range: rangeLower..<(rangeLower + formattedRows.count), totalRowCount: estimatedTotal, metrics: update.metrics, treatAsPreview: treatAsPreview, columns: streamingColumns)
                if treatAsPreview { spoolPreviewRows = formattedRows }
            }
        } else {
            let rangeLower = update.rowRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
            let displayCap = effectiveShouldPersist ? bufferLimit : max(frontBufferLimit, previewRowLimit)
            var immediateCount = 0
            if let range = update.rowRange, !update.appendedRows.isEmpty {
                immediateCount = max(0, min(update.appendedRows.count, min(rangeLower + appendedRowCount, displayCap) - rangeLower))
                if immediateCount > 0 {
                    let rows = immediateCount < update.appendedRows.count ? Array(update.appendedRows.prefix(immediateCount)) : update.appendedRows
                    integrateFormattedRows(rows: rows, range: range.lowerBound..<(range.lowerBound + rows.count), totalRowCount: estimatedTotal, metrics: update.metrics, treatAsPreview: treatAsPreview, columns: streamingColumns)
                    if treatAsPreview { spoolPreviewRows = rows }
                }
            } else if !update.rawRows.isEmpty {
                immediateCount = min(max(previewRowLimit - rowProgress.materialized, 0), min(update.rawRows.count, max(0, min(rangeLower + appendedRowCount, displayCap) - rangeLower)))
                if immediateCount > 0 {
                    let rows = formatRowsSynchronously(Array(update.rawRows.prefix(immediateCount)))
                    integrateFormattedRows(rows: rows, range: rangeLower..<(rangeLower + immediateCount), totalRowCount: estimatedTotal, metrics: update.metrics, treatAsPreview: true, columns: streamingColumns)
                    if treatAsPreview { spoolPreviewRows = rows }
                }
            }
            if update.rawRows.count > immediateCount {
                let deferredStart = (update.rowRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)) + immediateCount
                let deferredRows = Array(update.rawRows.dropFirst(immediateCount))
                enqueueDeferredBatch(rows: deferredRows, range: deferredStart..<(deferredStart + deferredRows.count), totalRowCount: estimatedTotal, metrics: update.metrics, treatAsPreview: false, columns: streamingColumns)
            }
        }

        let spoolPayload = QueryStreamUpdate(
            columns: update.columns,
            appendedRows: treatAsPreview ? (!spoolPreviewRows.isEmpty ? spoolPreviewRows : []) : (update.encodedRows.isEmpty && update.rawRows.isEmpty ? update.appendedRows : []),
            encodedRows: update.encodedRows,
            rawRows: update.rawRows,
            totalRowCount: update.totalRowCount,
            metrics: update.metrics,
            rowRange: update.rowRange
        )
        submitToSpool(update: spoolPayload, mode: modeForSpool)

        if appendedRowCount > 0 && spoolPreviewRows.isEmpty {
            let resTotal = estimatedTotal > 0 ? estimatedTotal : rowProgress.totalReported
            if resTotal > 0, streamedRowCount > resTotal { streamedRowCount = resTotal }
            rowProgress = RowProgress(totalReceived: resTotal > 0 ? min(max(streamedRowCount, rowProgress.totalReceived), resTotal) : max(streamedRowCount, rowProgress.totalReceived), totalReported: resTotal, materialized: resTotal > 0 ? min(rowProgress.materialized, resTotal) : rowProgress.materialized)
            markResultDataChanged()
        }

        if streamingMode == .preview, streamedRowCount >= spoolActivationThreshold {
            streamingMode = .background
            if !isResultsOnly { visibleRowLimit = nil }
            shouldPersistResults = true
        }
        if streamingMode == .preview || isExecuting { refreshLivePerformanceReport() }
        activateSpoolIfNeeded()
    }

    func consumeFinalResult(_ result: QueryResultSet) {
        let total = result.totalRowCount ?? result.rows.count
        performanceTracker.markResultSetReceived(totalRowCount: total)
        streamingMode = .completed; streamingColumns = result.columns
        shouldPersistResults = shouldPersistResults || total >= spoolActivationThreshold
        let truncated = Array(result.rows.prefix(shouldPersistResults ? frontBufferLimit : max(frontBufferLimit, total)))
        rowCache.ingest(rows: truncated, startingAt: 0)
        streamedRowCount = max(streamedRowCount, total)
        if streamingRows.count < truncated.count { streamingRows = truncated } else { for i in 0..<truncated.count { streamingRows[i] = truncated[i] } }
        results = QueryResultSet(columns: result.columns, rows: truncated, totalRowCount: total, commandTag: result.commandTag)
        rowProgress = RowProgress(materialized: max(rowProgress.materialized, truncated.count), reported: max(rowProgress.reported, total), received: streamedRowCount)
        materializedHighWaterMark = max(materializedHighWaterMark, rowProgress.materialized)
        visibleRowLimit = isResultsOnly ? min(initialVisibleRowBatch, total) : nil
        refreshMaterializedProgress(); markResultDataChanged(); refreshLivePerformanceReport()
        if shouldPersistResults { activateSpoolIfNeeded(); finalizeSpool(with: result) } else {
            shouldPersistResults = false; deferredSpoolUpdates.removeAll(); ingestionService = nil; spoolHandle = nil; resultSpoolID = nil; spoolStatsTask?.cancel(); spoolStatsTask = nil
        }
    }
}

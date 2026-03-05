import Foundation
import os.log
import os.signpost

extension QueryEditorState {

    func ensureRowsMaterialized(range: Range<Int>) {
        guard !range.isEmpty else { return }
        let token = formattingGeneration
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.formattingCoordinator.prioritize(range: range, token: token)
        }
        guard let handle = spoolHandle else { return }
        rowCache.prefetch(range: range, using: handle) { [weak self] fetchedRange in
            Task { @MainActor in
                self?.handleMaterializedRange(fetchedRange)
            }
        }
    }

    func handleMaterializedRange(_ fetchedRange: Range<Int>) {
        guard !fetchedRange.isEmpty else { return }

        refreshMaterializedProgress()

        let visibleRange = lastVisibleDisplayRange
        if visibleRange.isEmpty {
            enqueueVisibleRowReload(for: fetchedRange)
            return
        }

        let lower = max(fetchedRange.lowerBound, visibleRange.lowerBound)
        let upper = min(fetchedRange.upperBound, visibleRange.upperBound)
        guard lower < upper else { return }

        enqueueVisibleRowReload(for: lower..<upper)
    }

    func enqueueVisibleRowReload(for range: Range<Int>) {
        guard !range.isEmpty else { return }
        if pendingVisibleRowReloadIndexes == nil {
            pendingVisibleRowReloadIndexes = IndexSet()
        }
        pendingVisibleRowReloadIndexes?.insert(integersIn: range)
        markResultDataChanged(force: true)
    }

    func enqueueDeferredBatch(
        rows: [ResultRowPayload],
        range: Range<Int>,
        totalRowCount: Int,
        metrics: QueryStreamMetrics?,
        treatAsPreview: Bool,
        columns: [ColumnInfo]
    ) {
        guard !rows.isEmpty else { return }
        #if DEBUG
        print("[WorkspaceTab] integrateFormattedRows rows=\(rows.count) range=\(range) totalRowCount=\(totalRowCount)")
        #endif
        let token = formattingGeneration
        let resetTask = formattingResetTask
        Task.detached(priority: .utility) { [weak self] in
            if let resetTask {
                _ = await resetTask.value
            }
            guard let self else { return }
            await self.formattingCoordinator.enqueue(
                range: range,
                rows: rows,
                totalRowCount: totalRowCount,
                metrics: metrics,
                treatAsPreview: treatAsPreview,
                columns: columns,
                token: token
            )
        }
    }

    func handleFormattedBatch(_ batch: ResultRowFormattingCoordinator.FormattedBatch) {
        guard batch.token == formattingGeneration else { return }
        guard !batch.rows.isEmpty else { return }
        integrateFormattedRows(
            rows: batch.rows,
            range: batch.range,
            totalRowCount: batch.totalRowCount,
            metrics: batch.metrics,
            treatAsPreview: batch.treatAsPreview,
            columns: batch.columns
        )
    }

    func integrateFormattedRows(
        rows: [[String?]],
        range: Range<Int>,
        totalRowCount: Int,
        metrics: QueryStreamMetrics?,
        treatAsPreview: Bool,
        columns: [ColumnInfo]
    ) {
        guard !rows.isEmpty else { return }
        let gridPipelineLog = OSLog(subsystem: "dk.tippr.echo", category: .pointsOfInterest)
        os_log("IntegrateFormattedRows begin rows=%{public}d", log: gridPipelineLog, type: .info, rows.count)
        print("[Signpost] IntegrateFormattedRows begin rows=\(rows.count)")
        if #available(macOS 10.14, *) {
            os_signpost(.begin, log: gridPipelineLog, name: "IntegrateFormattedRows", "%{public}d rows", rows.count)
        }
        defer {
            os_log("IntegrateFormattedRows end", log: gridPipelineLog, type: .info)
            print("[Signpost] IntegrateFormattedRows end")
            if #available(macOS 10.14, *) {
                os_signpost(.end, log: gridPipelineLog, name: "IntegrateFormattedRows")
            }
        }
        if rowDiagnosticsEnabled {
            if totalRowCount >= 0 && range.upperBound > totalRowCount {
                debugReportRowAnomaly(stage: "integrateFormattedRows", message: "range \(range) overshoots total \(totalRowCount) rows=\(rows.count)")
            }
            if totalRowCount >= 0 && streamingRows.count > totalRowCount {
                debugReportRowAnomaly(stage: "integrateFormattedRows", message: "pre-merge streamingRows \(streamingRows.count) already exceeds total \(totalRowCount)")
            }
        }
        rowCache.ingest(rows: rows, startingAt: range.lowerBound)

        if range.lowerBound < streamingRows.count {
            let overlapEnd = min(range.upperBound, streamingRows.count)
            if overlapEnd > range.lowerBound {
                let overlapCount = overlapEnd - range.lowerBound
                for index in 0..<overlapCount {
                    streamingRows[range.lowerBound + index] = rows[index]
                }
            }
        }

        let bufferLimit = shouldPersistResults ? frontBufferLimit : max(frontBufferLimit, totalRowCount)
        if streamingRows.count < bufferLimit && range.upperBound > streamingRows.count {
            let insertionLower = max(streamingRows.count, range.lowerBound)
            let offset = insertionLower - range.lowerBound
            if offset < rows.count {
                let slice = rows[offset...]
                let remainingCapacity = bufferLimit - streamingRows.count
                if remainingCapacity > 0 {
                    streamingRows.append(contentsOf: slice.prefix(remainingCapacity))
#if DEBUG
                    if rowDiagnosticsEnabled {
                        let appendedSlice = Array(slice.prefix(remainingCapacity))
                        if let badIndex = appendedSlice.firstIndex(where: { $0.allSatisfy { $0 == nil } }) {
                            let absoluteRow = insertionLower + badIndex
                            debugReportRowAnomaly(stage: "integrateFormattedRows", message: "appended all-nil row at \(absoluteRow) columns=\(appendedSlice[badIndex].count)")
                        }
                    }
#endif
                }
            }
        }

        if totalRowCount >= 0 {
            let cappedTotal = totalRowCount
            if streamingRows.count > cappedTotal {
                streamingRows.removeSubrange(cappedTotal..<streamingRows.count)
            }
            rowCache.clamp(to: cappedTotal)
            if streamedRowCount > cappedTotal {
                streamedRowCount = cappedTotal
            }
            if materializedHighWaterMark > cappedTotal {
                materializedHighWaterMark = cappedTotal
            }
            if rowDiagnosticsEnabled && streamingRows.count > cappedTotal {
                debugReportRowAnomaly(stage: "integrateFormattedRows", message: "post-trim streamingRows \(streamingRows.count) still exceeds capped total \(cappedTotal)")
            }
        }

        let contiguous = computeContiguousMaterializedCount()
        materializedHighWaterMark = contiguous
        let newReported = max(totalRowCount, contiguous)
        let newReceived = max(streamedRowCount, contiguous)
        if rowProgress.totalReported != newReported
            || rowProgress.totalReceived != newReceived
            || rowProgress.materialized != contiguous {
            rowProgress = RowProgress(
                totalReceived: newReceived,
                totalReported: newReported,
                materialized: contiguous
            )
        }

        if isExecuting && streamingMode == .preview {
            let baselineLimit = max(visibleRowLimit ?? 0, initialVisibleRowBatch)
            let availableRows = rowProgress.materialized
            let cappedLimit = min(totalRowCount, baselineLimit, availableRows)
            if visibleRowLimit != cappedLimit {
                visibleRowLimit = cappedLimit
            }
        }

        let visibleRange = lastVisibleDisplayRange
        if visibleRange.isEmpty {
            enqueueVisibleRowReload(for: range)
        } else {
            let lower = max(range.lowerBound, visibleRange.lowerBound)
            let upper = min(range.upperBound, visibleRange.upperBound)
            if lower < upper {
                enqueueVisibleRowReload(for: lower..<upper)
            }
        }

        markResultDataChanged()
    }

    @MainActor
    func formatRowsSynchronously(_ payloads: [ResultRowPayload]) -> [[String?]] {
        guard !payloads.isEmpty else { return [] }
        return payloads.map { row in
            row.cells.enumerated().map { index, cell in
                payloadFormatter.stringValue(for: cell, columnIndex: index)
            }
        }
    }

    func debugReportRowAnomaly(stage: String, message: @autoclosure () -> String) {
        guard rowDiagnosticsEnabled else { return }
        print("[RowDiagnostics][\(stage)] \(message()) streamingRows=\(streamingRows.count) materialized=\(materializedHighWaterMark) reported=\(rowProgress.totalReported) received=\(rowProgress.totalReceived) streamedCount=\(streamedRowCount)")
    }

    func debugTrackRowCountChange(event: String, previous: Int, current: Int, details: @autoclosure () -> String) {
#if DEBUG
        guard rowDiagnosticsEnabled, previous != current else { return }
        print("[RowDiagnostics][\(event)] streamedRowCount \(previous) -> \(current) \(details())")
#endif
    }

    func computeContiguousMaterializedCount() -> Int {
        max(streamingRows.count, rowCache.contiguousMaterializedCount())
    }

    func refreshMaterializedProgress() {
        let contiguous = computeContiguousMaterializedCount()
        if contiguous > materializedHighWaterMark {
            materializedHighWaterMark = contiguous
            let reported = max(rowProgress.totalReported, materializedHighWaterMark)
            let received = max(streamedRowCount, rowProgress.totalReceived)
            rowProgress = RowProgress(
                totalReceived: received,
                totalReported: reported,
                materialized: materializedHighWaterMark
            )
            markResultDataChanged()
        }
    }

    func consumePendingVisibleRowReloadIndexes() -> IndexSet? {
        let pending = pendingVisibleRowReloadIndexes
        pendingVisibleRowReloadIndexes = nil
        return pending
    }

    func markResultDataChanged(force: Bool = false) {
        let snapshot = BroadcastSnapshot(
            rowCount: rowProgress.materialized,
            streamingRowsCount: streamingRows.count,
            visibleLimit: visibleRowLimit,
            streamingMode: streamingMode,
            columnCount: streamingColumns.count
        )
        if !force && lastBroadcastSnapshot == snapshot {
            return
        }
        lastBroadcastSnapshot = snapshot

        if !force && isResultChangeCoalesced {
            return
        }
        isResultChangeCoalesced = true
        rowCountRefreshHandler?()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.resultChangeToken &+= 1
            self.isResultChangeCoalesced = false
        }
    }
}

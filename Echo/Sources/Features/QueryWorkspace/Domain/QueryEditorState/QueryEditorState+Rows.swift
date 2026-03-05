import Foundation

extension QueryEditorState {

    var displayedColumns: [ColumnInfo] {
        if !streamingColumns.isEmpty { return streamingColumns }
        return results?.columns ?? []
    }

    var displayedRowCount: Int {
        let available = totalAvailableRowCount
        if let limit = visibleRowLimit {
            return min(limit, available)
        }
        return available
    }

    var totalAvailableRowCount: Int {
        let materialized = max(materializedHighWaterMark, streamingRows.count, rowProgress.materialized)
        if rowProgress.totalReported > 0 {
            return min(rowProgress.totalReported, materialized)
        }
        let received = max(streamedRowCount, rowProgress.totalReceived)
        return max(materialized, received)
    }

    func displayedRow(at index: Int) -> [String?]? {
        guard index >= 0 else { return nil }
        let count = displayedRowCount
        guard index < count else { return nil }

        if index < streamingRows.count {
            return streamingRows[index]
        }

        if let cached = rowCache.row(at: index) {
            return cached
        }

        if let resultRows = results?.rows, index < resultRows.count {
            return resultRows[index]
        }

        ensureRowsMaterialized(range: index..<(index + 1))
        let resolved = rowCache.row(at: index)
        if resolved == nil, rowDiagnosticsEnabled {
            debugReportRowAnomaly(
                stage: "displayedRow",
                message: "row \(index) unavailable after fetch (streamingRows=\(streamingRows.count) cacheContiguous=\(rowCache.contiguousMaterializedCount()) totalAvailable=\(totalAvailableRowCount))"
            )
        }
        return resolved
    }

    func valueForDisplay(row: Int, column: Int) -> String? {
        guard column >= 0 else { return nil }
        guard let rowValues = displayedRow(at: row) else {
            ensureRowsMaterialized(range: row..<(row + 1))
#if DEBUG
            if rowDiagnosticsEnabled {
                debugReportRowAnomaly(stage: "valueForDisplay", message: "row \(row) unavailable for column \(column)")
            }
#endif
            return nil
        }
        if column >= rowValues.count {
            ensureRowsMaterialized(range: row..<(row + 1))
#if DEBUG
            if rowDiagnosticsEnabled {
                debugReportRowAnomaly(stage: "valueForDisplay", message: "row \(row) column \(column) beyond count \(rowValues.count)")
            }
#endif
            return nil
        }
        return rowValues[column]
    }

    func recordTableViewUpdate(visibleRowCount: Int, totalAvailableRowCount: Int) {
        performanceTracker.recordTableReload()
        guard totalAvailableRowCount > 0 else { return }
        let threshold = min(initialVisibleRowBatch, totalAvailableRowCount)
        if visibleRowCount >= threshold {
            performanceTracker.recordVisibleInitialLimitSatisfied()
        }
    }

    func revealMoreRowsIfNeeded(forDisplayedRow row: Int) {
        guard isExecuting || isResultsOnly else { return }
        guard let limit = visibleRowLimit else { return }

        let threshold = max(limit - max(initialVisibleRowBatch / 4, 50), 0)
        guard row >= threshold else { return }

        let available = totalAvailableRowCount
        if available > limit {
            let newLimit = min(limit + initialVisibleRowBatch, available)
            if newLimit > limit {
                visibleRowLimit = newLimit
                if isResultsOnly {
                    markResultDataChanged()
                }
            }
            return
        }

        if isResultsOnly {
            requestAdditionalDataPreviewRows()
        }
    }

    func updateVisibleGridWindow(displayedRange: Range<Int>, sourceIndices: [Int]) {
        lastVisibleDisplayRange = displayedRange
        guard !sourceIndices.isEmpty else { return }

        let sorted = Array(Set(sourceIndices)).sorted()
        guard let minSource = sorted.first, let maxSource = sorted.last else {
            return
        }

        let available = totalAvailableRowCount
        let lower = max(minSource - gridViewportBackfillRows, 0)
        let desiredUpper = maxSource + 1 + gridViewportForwardPrefetchRows
        let upper = max(lower, min(desiredUpper, max(available, desiredUpper)))
        let targetRange = lower..<upper
        guard !targetRange.isEmpty else { return }

        lastPrefetchedSourceRange = targetRange

        ensureRowsMaterialized(range: targetRange)
    }
}

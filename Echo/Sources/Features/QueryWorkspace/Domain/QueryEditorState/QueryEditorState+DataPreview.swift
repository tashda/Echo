import Foundation

extension QueryEditorState {

    func requestAdditionalDataPreviewRows() {
        guard var preview = dataPreviewState else { return }
        guard preview.hasMoreData, !preview.isFetching else { return }

        let offset = preview.nextOffset
        let limit = preview.batchSize

        preview.isFetching = true
        dataPreviewState = preview

        let fetcher = preview.fetcher
        dataPreviewFetchTask?.cancel()
        dataPreviewFetchTask = Task { [weak self] in
            do {
                let result = try await fetcher(offset, limit)
                await MainActor.run {
                    self?.handleAdditionalPreviewResult(result, requestedOffset: offset, requestedLimit: limit)
                }
            } catch {
                await MainActor.run {
                    self?.handleAdditionalPreviewFailure(error)
                }
            }
        }
    }

    private func handleAdditionalPreviewResult(
        _ result: QueryResultSet,
        requestedOffset: Int,
        requestedLimit: Int
    ) {
        dataPreviewFetchTask = nil
        guard var preview = dataPreviewState else { return }

        let newRows = result.rows
        if streamingColumns.isEmpty {
            streamingColumns = result.columns
        }

        if !newRows.isEmpty {
            let startIndex = streamedRowCount
            rowCache.ingest(rows: newRows, startingAt: startIndex)
            streamedRowCount += newRows.count
            debugTrackRowCountChange(
                event: "previewFetch",
                previous: startIndex,
                current: streamedRowCount,
                details: "fetched=\(newRows.count) requestedOffset=\(requestedOffset) requestedLimit=\(requestedLimit)"
            )

            let bufferLimit = shouldPersistResults ? frontBufferLimit : max(frontBufferLimit, streamedRowCount)
            if streamingRows.count < bufferLimit {
                let remainingCapacity = bufferLimit - streamingRows.count
                if remainingCapacity > 0 {
                    streamingRows.append(contentsOf: newRows.prefix(remainingCapacity))
                }
            }

            refreshMaterializedProgress()

            let newTotal = streamedRowCount
            let newMaterialized = max(rowProgress.materialized, streamingRows.count)
            let newReported = max(rowProgress.reported, newTotal)
            if rowProgress.materialized != newMaterialized
                || rowProgress.totalReported != newReported
                || rowProgress.totalReceived != streamedRowCount {
                rowProgress = RowProgress(
                    totalReceived: streamedRowCount,
                    totalReported: newReported,
                    materialized: newMaterialized
                )
            }
            let currentLimit = visibleRowLimit ?? initialVisibleRowBatch
            let expandedLimit = min(newTotal, currentLimit + newRows.count)
            visibleRowLimit = expandedLimit

            if var existingResult = results {
                existingResult.columns = streamingColumns
                existingResult.rows = streamingRows
                existingResult.totalRowCount = newReported
                results = existingResult
            } else {
                results = QueryResultSet(
                    columns: streamingColumns,
                    rows: streamingRows,
                    totalRowCount: newReported
                )
            }

            markResultDataChanged()
        }

        preview.nextOffset = requestedOffset + newRows.count
        preview.hasMoreData = newRows.count >= preview.batchSize
        preview.isFetching = false
        dataPreviewState = preview

        if newRows.isEmpty {
            let newReported = max(rowProgress.totalReported, streamedRowCount)
            if rowProgress.totalReported != newReported || rowProgress.totalReceived != streamedRowCount {
                rowProgress = RowProgress(
                    totalReceived: streamedRowCount,
                    totalReported: newReported,
                    materialized: rowProgress.materialized
                )
            }
        }

        if newRows.isEmpty {
            appendMessage(
                message: "No additional data available",
                severity: .info,
                category: "Data Preview"
            )
        } else if newRows.count < requestedLimit {
            appendMessage(
                message: "Loaded \(newRows.count) additional rows (end of results)",
                severity: .info,
                category: "Data Preview"
            )
        } else {
            appendMessage(
                message: "Loaded \(newRows.count) additional rows",
                severity: .info,
                category: "Data Preview"
            )
        }
    }

    private func handleAdditionalPreviewFailure(_ error: Error) {
        dataPreviewFetchTask = nil
        if var preview = dataPreviewState {
            preview.isFetching = false
            dataPreviewState = preview
        }
        let nsError = error as NSError
        appendMessage(
            message: "Failed to load additional preview rows",
            severity: .error,
            category: "Data Preview",
            metadata: ["error": nsError.localizedDescription]
        )
    }
}

import Foundation

final class ResultStreamBatchWorker: @unchecked Sendable {
    struct Payload: Sendable {
        let previewValues: [String?]?
        let encodedRow: ResultBinaryRow
        let totalRowCount: Int
        let decodeDuration: TimeInterval
    }

    private let queue: DispatchQueue
    private let progressHandler: QueryProgressHandler
    private let columns: [ColumnInfo]
    private let streamingPreviewLimit: Int
    private let maxFlushLatency: TimeInterval
    private let operationStart: CFAbsoluteTime

    private var pendingPreviewRows: [[String?]] = []
    private var pendingEncodedRows: [ResultBinaryRow] = []
    private var lastFlushTimestamp: CFAbsoluteTime
    private var batchDecodeDuration: TimeInterval = 0
    private var previewRowsEmitted: Int = 0

    init(
        label: String,
        columns: [ColumnInfo],
        streamingPreviewLimit: Int,
        maxFlushLatency: TimeInterval,
        operationStart: CFAbsoluteTime,
        progressHandler: @escaping QueryProgressHandler
    ) {
        self.queue = DispatchQueue(label: label, qos: .userInitiated)
        self.columns = columns
        self.streamingPreviewLimit = streamingPreviewLimit
        self.maxFlushLatency = maxFlushLatency
        self.operationStart = operationStart
        self.progressHandler = progressHandler
        self.lastFlushTimestamp = operationStart
    }

    nonisolated func enqueue(_ payload: Payload) {
        queue.async {
            if let preview = payload.previewValues, self.previewRowsEmitted < self.streamingPreviewLimit {
                self.pendingPreviewRows.append(preview)
                self.previewRowsEmitted += 1
            }

            self.pendingEncodedRows.append(payload.encodedRow)
            self.batchDecodeDuration += payload.decodeDuration

            let threshold = self.flushThreshold(for: payload.totalRowCount)
            let elapsed = CFAbsoluteTimeGetCurrent() - self.lastFlushTimestamp
            let latencyBudget = self.latencyBudget(for: payload.totalRowCount)
            let fallbackBudget = self.fallbackLatency(for: payload.totalRowCount)

            if self.pendingEncodedRows.count >= threshold
                || (elapsed >= latencyBudget && !self.pendingEncodedRows.isEmpty)
                || elapsed >= fallbackBudget {
                self.flush(totalRowCount: payload.totalRowCount)
            }
        }
    }

    nonisolated func finish(totalRowCount: Int) {
        queue.sync {
            self.flush(totalRowCount: totalRowCount)
        }
    }

    private func flush(totalRowCount: Int) {
        guard !pendingEncodedRows.isEmpty else { return }

        let previewBatch = pendingPreviewRows
        let encodedBatch = pendingEncodedRows
        let batchCount = encodedBatch.count
        pendingPreviewRows.removeAll(keepingCapacity: true)
        pendingEncodedRows.removeAll(keepingCapacity: true)

        let now = CFAbsoluteTimeGetCurrent()
        let metrics = QueryStreamMetrics(
            batchRowCount: batchCount,
            loopElapsed: now - lastFlushTimestamp,
            decodeDuration: batchDecodeDuration,
            totalElapsed: now - operationStart,
            cumulativeRowCount: totalRowCount
        )
        lastFlushTimestamp = now
        batchDecodeDuration = 0

#if DEBUG
        if batchCount <= 2 && metrics.loopElapsed > 0.2 {
            print("[ResultStreamBatchWorker] small flush size=\(batchCount) total=\(totalRowCount) elapsed=\(metrics.totalElapsed)s latency=\(metrics.loopElapsed)s")
        } else if totalRowCount >= 1_000 && totalRowCount % 5_000 == 0 {
            print("[ResultStreamBatchWorker] checkpoint total=\(totalRowCount) elapsed=\(metrics.totalElapsed)s")
        }
#endif

        let batchStartIndex = max(totalRowCount - batchCount, 0)

        let update = QueryStreamUpdate(
            columns: columns,
            appendedRows: previewBatch,
            encodedRows: encodedBatch,
            totalRowCount: totalRowCount,
            metrics: metrics,
            rowRange: batchCount > 0 ? (batchStartIndex..<totalRowCount) : nil
        )
        progressHandler(update)
    }

    private func flushThreshold(for totalCount: Int) -> Int {
        if totalCount <= streamingPreviewLimit {
            return 24
        }
        if totalCount <= streamingPreviewLimit * 4 {
            return 256
        }
        if totalCount <= 128_000 {
            return 512
        }
        return 1_024
    }

    private func latencyBudget(for totalCount: Int) -> TimeInterval {
        if totalCount <= streamingPreviewLimit {
            return min(maxFlushLatency, 0.035)
        }
        if totalCount <= streamingPreviewLimit * 4 {
            return min(maxFlushLatency, 0.05)
        }
        return min(maxFlushLatency, 0.075)
    }

    private func fallbackLatency(for totalCount: Int) -> TimeInterval {
        if totalCount <= streamingPreviewLimit {
            return max(0.12, maxFlushLatency * 0.5)
        }
        if totalCount <= streamingPreviewLimit * 4 {
            return max(0.18, maxFlushLatency * 0.6)
        }
        return max(0.25, maxFlushLatency * 0.7)
    }
}

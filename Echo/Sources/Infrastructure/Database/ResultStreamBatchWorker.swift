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
    private var hasEmittedBatch = false

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
            let previewPhase = payload.totalRowCount <= self.streamingPreviewLimit
            let minLatencyBatch = previewPhase ? min(16, threshold) : min(64, threshold)
            let fallbackBudget: TimeInterval = previewPhase
                ? max(latencyBudget * 2, 1.0)
                : max(latencyBudget * 1.5, 0.8)

            var shouldFlush = false
            if self.pendingEncodedRows.count >= threshold {
                shouldFlush = true
            } else if elapsed >= latencyBudget && self.pendingEncodedRows.count >= minLatencyBatch {
                shouldFlush = true
            } else if elapsed >= fallbackBudget {
                shouldFlush = true
            }

            if shouldFlush {
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
        pendingPreviewRows.removeAll(keepingCapacity: true)
        pendingEncodedRows.removeAll(keepingCapacity: true)

        let now = CFAbsoluteTimeGetCurrent()
        let metrics = QueryStreamMetrics(
            batchRowCount: encodedBatch.count,
            loopElapsed: now - lastFlushTimestamp,
            decodeDuration: batchDecodeDuration,
            totalElapsed: now - operationStart,
            cumulativeRowCount: totalRowCount
        )
        lastFlushTimestamp = now
        batchDecodeDuration = 0
        hasEmittedBatch = true

#if DEBUG
        if encodedBatch.count <= 2 && metrics.loopElapsed > 0.25 {
            print("[ResultStreamBatchWorker] small flush size=\(encodedBatch.count) total=\(totalRowCount) elapsed=\(metrics.totalElapsed)s latency=\(metrics.loopElapsed)s")
        } else if totalRowCount >= 1_000 && totalRowCount % 5_000 == 0 {
            print("[ResultStreamBatchWorker] checkpoint total=\(totalRowCount) elapsed=\(metrics.totalElapsed)s")
        }
#endif

        let update = QueryStreamUpdate(
            columns: columns,
            appendedRows: previewBatch,
            encodedRows: encodedBatch,
            totalRowCount: totalRowCount,
            metrics: metrics
        )
        progressHandler(update)
    }

    private func flushThreshold(for totalCount: Int) -> Int {
        if totalCount <= streamingPreviewLimit {
            return 64
        }
        if totalCount <= streamingPreviewLimit * 4 {
            return 1_024
        }
        if totalCount <= 128_000 {
            return 2_048
        }
        return 4_096
    }

    private func latencyBudget(for totalCount: Int) -> TimeInterval {
        if totalCount <= streamingPreviewLimit {
            return maxFlushLatency
        }
        return max(maxFlushLatency, 0.5)
    }
}

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

    private struct FlushPolicy {
        let threshold: Int
        let minimumBatch: Int
        let latencyBatch: Int
        let latencyBudget: TimeInterval
        let fallbackLatency: TimeInterval
        let fallbackBatch: Int
    }

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

            let elapsed = CFAbsoluteTimeGetCurrent() - self.lastFlushTimestamp
            let policy = self.flushPolicy(for: payload.totalRowCount)
            let pendingCount = self.pendingEncodedRows.count

            let meetsThreshold = pendingCount >= policy.threshold
            let meetsMinimumBatch = pendingCount >= policy.minimumBatch
            let meetsLatencyBatch = elapsed >= policy.latencyBudget && pendingCount >= policy.latencyBatch
            let meetsFallback = elapsed >= policy.fallbackLatency && pendingCount >= policy.fallbackBatch

            if meetsThreshold || meetsMinimumBatch || meetsLatencyBatch || meetsFallback {
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

    private func flushPolicy(for totalCount: Int) -> FlushPolicy {
        if totalCount <= streamingPreviewLimit {
            let threshold = clamp(streamingPreviewLimit / 8, min: 32, max: 128)
            let minimumBatch = threshold
            let latencyBatch = threshold
            let fallbackBatch = max(threshold / 2, 24)
            let latencyBudget = min(maxFlushLatency, 0.045)
            let fallbackLatency = max(0.18, maxFlushLatency * 0.45)
            return FlushPolicy(
                threshold: threshold,
                minimumBatch: minimumBatch,
                latencyBatch: latencyBatch,
                latencyBudget: latencyBudget,
                fallbackLatency: fallbackLatency,
                fallbackBatch: fallbackBatch
            )
        } else {
            let threshold = max(streamingPreviewLimit, 512)
            let minimumBatch = threshold
            let latencyBatch = threshold
            let fallbackBatch = max(threshold / 4, 128)
            let latencyBudget = min(maxFlushLatency, 0.08)
            let fallbackLatency = max(0.32, maxFlushLatency * 0.6)
            return FlushPolicy(
                threshold: threshold,
                minimumBatch: minimumBatch,
                latencyBatch: latencyBatch,
                latencyBudget: latencyBudget,
                fallbackLatency: fallbackLatency,
                fallbackBatch: fallbackBatch
            )
        }
    }

    private func clamp(_ value: Int, min: Int, max: Int) -> Int {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}

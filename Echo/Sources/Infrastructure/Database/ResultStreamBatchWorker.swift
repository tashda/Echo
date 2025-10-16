import Foundation

final class ResultStreamBatchWorker {
    struct Payload {
        let previewValues: [String?]?
        let totalRowCount: Int
        let decodeDuration: TimeInterval
        let encode: @Sendable () -> ResultBinaryRow
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

    func enqueue(_ payload: Payload) {
        queue.async {
            if let preview = payload.previewValues, self.previewRowsEmitted < self.streamingPreviewLimit {
                self.pendingPreviewRows.append(preview)
                self.previewRowsEmitted += 1
            }

            let encodedRow = payload.encode()
            self.pendingEncodedRows.append(encodedRow)
            self.batchDecodeDuration += payload.decodeDuration

            let threshold = self.flushThreshold(for: payload.totalRowCount)
            let elapsed = CFAbsoluteTimeGetCurrent() - self.lastFlushTimestamp
            if self.pendingEncodedRows.count >= threshold || elapsed >= self.maxFlushLatency {
                self.flush(totalRowCount: payload.totalRowCount)
            }
        }
    }

    func finish(totalRowCount: Int) {
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
        switch totalCount {
        case 0..<1024:
            return 32
        case 1024..<8192:
            return 128
        case 8192..<32_768:
            return 512
        default:
            return 1_024
        }
    }
}

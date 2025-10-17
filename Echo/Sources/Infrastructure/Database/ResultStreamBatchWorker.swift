import Foundation
import NIOCore

final class ResultStreamBatchWorker: @unchecked Sendable {
    struct RawRow: @unchecked Sendable {
        let buffers: [ByteBuffer?]
        let lengths: [Int]
        let totalLength: Int
    }

    enum BinaryRowStorage: @unchecked Sendable {
        case encoded(ResultBinaryRow)
        case raw(RawRow)
    }

    struct Payload: Sendable {
        let previewValues: [String?]?
        let storage: BinaryRowStorage
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
    private var pendingRows: [BinaryRowStorage] = []
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
            self.processPayload(payload)
        }
    }

    nonisolated func enqueueRaw(
        previewValues: [String?]?,
        buffers: [ByteBuffer?],
        lengths: [Int],
        totalLength: Int,
        totalRowCount: Int,
        decodeDuration: TimeInterval
    ) {
        queue.async {
            let raw = RawRow(buffers: buffers, lengths: lengths, totalLength: totalLength)
            let payload = Payload(
                previewValues: previewValues,
                storage: .raw(raw),
                totalRowCount: totalRowCount,
                decodeDuration: decodeDuration
            )
            self.processPayload(payload)
        }
    }

    nonisolated func finish(totalRowCount: Int) {
        queue.sync {
            self.flush(totalRowCount: totalRowCount)
        }
    }

    private func processPayload(_ payload: Payload) {
        if let preview = payload.previewValues, previewRowsEmitted < streamingPreviewLimit {
            pendingPreviewRows.append(preview)
            previewRowsEmitted += 1
        }

        pendingRows.append(payload.storage)
        batchDecodeDuration += payload.decodeDuration

        let elapsed = CFAbsoluteTimeGetCurrent() - lastFlushTimestamp
        let policy = flushPolicy(for: payload.totalRowCount)
        let pendingCount = pendingRows.count

        let meetsThreshold = pendingCount >= policy.threshold
        let meetsMinimumBatch = pendingCount >= policy.minimumBatch
        let meetsLatencyBatch = elapsed >= policy.latencyBudget && pendingCount >= policy.latencyBatch
        let meetsFallback = elapsed >= policy.fallbackLatency && pendingCount >= policy.fallbackBatch

        if meetsThreshold || meetsMinimumBatch || meetsLatencyBatch || meetsFallback {
            flush(totalRowCount: payload.totalRowCount)
        }
    }

    private func flush(totalRowCount: Int) {
        guard !pendingRows.isEmpty else { return }

        let previewBatch = pendingPreviewRows
        let storageBatch = pendingRows
        let batchCount = storageBatch.count
        var encodedBatch: [ResultBinaryRow] = []
        encodedBatch.reserveCapacity(batchCount)

        for storage in storageBatch {
            switch storage {
            case .encoded(let row):
                encodedBatch.append(row)
            case .raw(let raw):
                let row = ResultStreamBatchWorker.encodeBinaryRow(
                    totalLength: raw.totalLength,
                    buffers: raw.buffers,
                    lengths: raw.lengths
                )
                encodedBatch.append(row)
            }
        }

        pendingRows.removeAll(keepingCapacity: true)
        pendingPreviewRows.removeAll(keepingCapacity: true)
        let finalBatch = encodedBatch

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
            encodedRows: finalBatch,
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

    static func encodeBinaryRow(totalLength: Int, buffers: [ByteBuffer?], lengths: [Int]) -> ResultBinaryRow {
        var data = Data(count: totalLength)
        data.withUnsafeMutableBytes { mutableBytes in
            guard let baseAddress = mutableBytes.baseAddress else { return }
            var offset = 0

            for index in 0..<lengths.count {
                let length = lengths[index]
                if length < 0 {
                    baseAddress.storeBytes(of: UInt8(0x00), toByteOffset: offset, as: UInt8.self)
                    offset &+= 1
                    continue
                }

                baseAddress.storeBytes(of: UInt8(0x01), toByteOffset: offset, as: UInt8.self)
                offset &+= 1

                var littleEndianLength = UInt32(length).littleEndian
                withUnsafeBytes(of: &littleEndianLength) { pointer in
                    memcpy(baseAddress.advanced(by: offset), pointer.baseAddress!, 4)
                }
                offset &+= 4

                if length > 0, let buffer = buffers[index] {
                    buffer.withUnsafeReadableBytes { rawBuffer in
                        memcpy(baseAddress.advanced(by: offset), rawBuffer.baseAddress!, length)
                    }
                }
                offset &+= length
            }
        }
        return ResultBinaryRow(data: data)
    }
}

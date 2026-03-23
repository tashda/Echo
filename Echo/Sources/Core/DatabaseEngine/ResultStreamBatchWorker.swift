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
        case stringValues([String?])
        /// Deferred string conversion — the closure is called on the worker's GCD queue,
        /// not on the hot row-iteration path. Used by MSSQL to defer expensive per-cell
        /// type decoding to a background thread.
        case deferred(@Sendable () -> [String?])
    }

    private struct SendableBufferPointer<Element>: @unchecked Sendable {
        var buffer: UnsafeMutableBufferPointer<Element>
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

    /// Direct spool writer — when set, binary-only batches are written directly to disk
    /// on the worker's serial queue, bypassing the MainActor → ingestion actor pipeline.
    private var spoolWriter: SynchronousSpoolWriter?
    private var spoolHeaderWritten = false

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

    nonisolated init(
        label: String,
        columns: [ColumnInfo],
        streamingPreviewLimit: Int,
        maxFlushLatency: TimeInterval,
        operationStart: CFAbsoluteTime,
        progressHandler: @escaping QueryProgressHandler,
        spoolWriter: SynchronousSpoolWriter? = nil
    ) {
        self.queue = DispatchQueue(label: label, qos: .userInitiated)
        self.columns = columns
        self.streamingPreviewLimit = streamingPreviewLimit
        self.maxFlushLatency = maxFlushLatency
        self.operationStart = operationStart
        self.progressHandler = progressHandler
        self.spoolWriter = spoolWriter
        self.lastFlushTimestamp = operationStart
    }

    nonisolated func enqueue(_ payload: Payload) {
        queue.async {
            self.processPayload(payload)
        }
    }

    nonisolated func enqueueBatch(_ payloads: [Payload]) {
        guard !payloads.isEmpty else { return }
        queue.async {
            for payload in payloads {
                self.processPayload(payload)
            }
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

    nonisolated func finish(totalRowCount: Int, completion: (@Sendable () -> Void)? = nil) {
        queue.async {
            self.flush(totalRowCount: totalRowCount)
            completion?()
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
        let policy = flushPolicy(
            totalCount: payload.totalRowCount,
            hasPreviewRows: !pendingPreviewRows.isEmpty
        )
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
        let hasPreviewRows = !previewBatch.isEmpty
        let shouldParallelize = batchCount >= 1_024
        let encodedBatch: [ResultBinaryRow] = {
            if !shouldParallelize {
                return storageBatch.map { storage in
                    switch storage {
                    case .encoded(let row):
                        return row
                    case .raw(let raw):
                        return ResultStreamBatchWorker.encodeBinaryRow(
                            totalLength: raw.totalLength,
                            buffers: raw.buffers,
                            lengths: raw.lengths
                        )
                    case .stringValues(let values):
                        return ResultBinaryRowCodec.encode(row: values)
                    case .deferred(let convert):
                        return ResultBinaryRowCodec.encode(row: convert())
                    }
                }
            }

            var buffer = Array<ResultBinaryRow?>(repeating: nil, count: batchCount)
            let concurrency = ProcessInfo.processInfo.processorCount
            buffer.withUnsafeMutableBufferPointer { pointer in
                let sendablePointer = SendableBufferPointer(buffer: pointer)
                DispatchQueue.concurrentPerform(iterations: concurrency) { workerIndex in
                    let pointer = sendablePointer.buffer
                    var index = workerIndex
                    while index < batchCount {
                        let storage = storageBatch[index]
                        let encodedRow: ResultBinaryRow
                        switch storage {
                        case .encoded(let row):
                            encodedRow = row
                        case .raw(let raw):
                            encodedRow = ResultStreamBatchWorker.encodeBinaryRow(
                                totalLength: raw.totalLength,
                                buffers: raw.buffers,
                                lengths: raw.lengths
                            )
                        case .stringValues(let values):
                            encodedRow = ResultBinaryRowCodec.encode(row: values)
                        case .deferred(let convert):
                            encodedRow = ResultBinaryRowCodec.encode(row: convert())
                        }
                        pointer[index] = encodedRow
                        index &+= concurrency
                    }
                }
            }
            return buffer.compactMap { $0 }
        }()

        pendingRows.removeAll(keepingCapacity: true)
        pendingPreviewRows.removeAll(keepingCapacity: true)

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

        // Direct spool write path: write binary rows directly to disk on this queue,
        // then send a count-only update to the progress handler (no row data).
        if let writer = spoolWriter, !hasPreviewRows {
            if !spoolHeaderWritten {
                try? writer.writeHeader(columns: columns)
                spoolHeaderWritten = true
            }
            writer.appendEncodedRows(encodedBatch, startRow: batchStartIndex)

            // Send lightweight count-only update (empty row arrays)
            let update = QueryStreamUpdate(
                columns: columns,
                appendedRows: [],
                encodedRows: [],
                totalRowCount: totalRowCount,
                metrics: metrics,
                rowRange: batchCount > 0 ? (batchStartIndex..<totalRowCount) : nil
            )
            progressHandler(update)
            return
        }

        // Standard path: send rows through the progress handler for MainActor processing
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

    private func flushPolicy(totalCount: Int, hasPreviewRows: Bool) -> FlushPolicy {
        if hasPreviewRows || totalCount <= streamingPreviewLimit {
            let threshold = min(max(streamingPreviewLimit / 4, 48), 196)
            let minimumBatch = max(threshold / 2, 32)
            let latencyBatch = max(threshold / 2, 32)
            let fallbackBatch = max(min(threshold / 2, 64), 24)
            let latencyBudget = min(maxFlushLatency, 0.040)
            let fallbackLatency = max(0.12, maxFlushLatency * 0.30)
            return FlushPolicy(
                threshold: threshold,
                minimumBatch: minimumBatch,
                latencyBatch: latencyBatch,
                latencyBudget: latencyBudget,
                fallbackLatency: fallbackLatency,
                fallbackBatch: fallbackBatch
            )
        } else {
            let threshold = 8_192
            let minimumBatch = threshold
            let latencyBatch = 2_048
            let fallbackBatch = 256
            let latencyBudget: TimeInterval = 0.10
            let fallbackLatency: TimeInterval = 0.15
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
                    guard let pointerBase = pointer.baseAddress else { return }
                    memcpy(baseAddress.advanced(by: offset), pointerBase, 4)
                }
                offset &+= 4

                if length > 0, let buffer = buffers[index] {
                    buffer.withUnsafeReadableBytes { rawBuffer in
                        guard let rawBase = rawBuffer.baseAddress else { return }
                        memcpy(baseAddress.advanced(by: offset), rawBase, length)
                    }
                }
                offset &+= length
            }
        }
        return ResultBinaryRow(data: data)
    }
}

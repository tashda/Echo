import Foundation
import NIOCore
import PostgresKit
import PostgresWire
import Logging

actor QueryStreamState {
    var columns: [ColumnInfo] = []
    var previewRows: [[String?]] = []
    var totalRowCount = 0
    var batchDecodeDuration: TimeInterval = 0
    var batchCount = 0
    var rawPayloadRows: [ResultRowPayload] = []
    var batchRows: [[String?]] = []
    var encodedRows: [ResultBinaryRow] = []
    var firstRowLogged = false
    var flushRequestRowCount: Int
    var batchStartTime: CFAbsoluteTime
    var dynamicBackgroundFlushSize: Int
    var firstBatchDelivered = false
    var commandTag: String?
    var lastProgressPublish: CFAbsoluteTime
    var lastProgressReported: Int

    let streamingPreviewLimit: Int
    let formatterContext: CellFormatterContext
    let formattingEnabled: Bool
    let formattingMode: ResultsFormattingMode
    let logger: Logger
    let operationStart: CFAbsoluteTime
    let streamDebugID: String?

    init(streamingPreviewLimit: Int,
         formatterContext: CellFormatterContext,
         formattingEnabled: Bool,
         formattingMode: ResultsFormattingMode,
         logger: Logger,
         operationStart: CFAbsoluteTime,
         streamDebugID: String?,
         previewFetchSize: Int,
         backgroundFetchBaseline: Int) {
        self.streamingPreviewLimit = streamingPreviewLimit
        self.formatterContext = formatterContext
        self.formattingEnabled = formattingEnabled
        self.formattingMode = formattingMode
        self.logger = logger
        self.operationStart = operationStart
        self.streamDebugID = streamDebugID
        self.flushRequestRowCount = previewFetchSize
        self.batchStartTime = operationStart
        self.dynamicBackgroundFlushSize = backgroundFetchBaseline
        self.lastProgressPublish = operationStart
        self.lastProgressReported = 0
    }

    func appendColumn(_ column: ColumnInfo) {
        columns.append(column)
    }

    func appendRawPayloadRow(_ rowPayload: ResultRowPayload) {
        rawPayloadRows.append(rowPayload)
    }

    func appendFormattedRow(_ formattedRow: [String?]) {
        batchRows.append(formattedRow)
    }

    func appendEncodedRow(_ encodedRow: ResultBinaryRow) {
        encodedRows.append(encodedRow)
    }

    func appendPreviewRow(_ formattedRow: [String?]) {
        if previewRows.count < streamingPreviewLimit {
            previewRows.append(formattedRow)
        }
    }

    func setColumns(_ newColumns: [ColumnInfo]) {
        columns = newColumns
    }

    func incrementCounts(decodeDuration: TimeInterval) {
        totalRowCount += 1
        batchCount += 1
        batchDecodeDuration += decodeDuration
    }

    func setFirstRowLogged() {
        firstRowLogged = true
    }

    func resetBatch() {
        batchRows.removeAll(keepingCapacity: true)
        encodedRows.removeAll(keepingCapacity: true)
        rawPayloadRows.removeAll(keepingCapacity: true)
        batchCount = 0
        batchDecodeDuration = 0
        batchStartTime = CFAbsoluteTimeGetCurrent()
    }

    func incrementTotalOnly() {
        totalRowCount &+= 1
    }

    func updateFlushRequestRowCount(
        rampMaxRows: Int,
        backgroundFetchBaseline: Int,
        previewFetchSize: Int,
        rampEligible: Bool,
        rampMultiplier: Int
    ) {
        if totalRowCount >= streamingPreviewLimit {
            if dynamicBackgroundFlushSize < backgroundFetchBaseline {
                dynamicBackgroundFlushSize = backgroundFetchBaseline
            }

            if rampEligible, dynamicBackgroundFlushSize < rampMaxRows {
                let targetByDoubling = max(dynamicBackgroundFlushSize, backgroundFetchBaseline) * 2
                let targetByMultiplier = backgroundFetchBaseline * max(1, rampMultiplier)
                let candidate = max(targetByDoubling, targetByMultiplier)
                let nextSize = min(rampMaxRows, candidate)
                if nextSize > dynamicBackgroundFlushSize {
                    dynamicBackgroundFlushSize = nextSize
                }
            }

            flushRequestRowCount = min(dynamicBackgroundFlushSize, rampMaxRows)
        } else {
            flushRequestRowCount = previewFetchSize
        }
    }

    func setFirstBatchDelivered() {
        firstBatchDelivered = true
    }

    func setCommandTag(_ tag: String?) {
        commandTag = tag
    }

    func debugLog(_ message: @autoclosure @Sendable () -> String) {
        guard let streamDebugID else { return }
        let elapsed = CFAbsoluteTimeGetCurrent() - operationStart
        print("[PostgresStream][\(streamDebugID)] t=\(String(format: "%.3f", elapsed)) \(message())")
    }

    func publishBatch(expectedRequestSize: Int, rampEligible: Bool, progressHandler: @escaping QueryProgressHandler) async {
        guard batchCount > 0 || !encodedRows.isEmpty || !rawPayloadRows.isEmpty else { return }
        let flushedCount = batchCount > 0 ? batchCount : (!encodedRows.isEmpty ? encodedRows.count : rawPayloadRows.count)
        let flushDuration = CFAbsoluteTimeGetCurrent() - batchStartTime
        let networkWait = max(flushDuration - batchDecodeDuration, 0)
        let rowRange = (totalRowCount - flushedCount)..<totalRowCount

        let metrics = QueryStreamMetrics(
            batchRowCount: flushedCount,
            loopElapsed: flushDuration,
            decodeDuration: batchDecodeDuration,
            totalElapsed: CFAbsoluteTimeGetCurrent() - operationStart,
            cumulativeRowCount: totalRowCount,
            fetchRequestRowCount: expectedRequestSize,
            fetchRowCount: flushedCount,
            fetchDuration: flushDuration,
            fetchWait: networkWait
        )

        let update = QueryStreamUpdate(
            columns: columns,
            appendedRows: batchRows,
            encodedRows: encodedRows,
            rawRows: rawPayloadRows,
            totalRowCount: totalRowCount,
            metrics: metrics,
            rowRange: rowRange
        )

        if !firstBatchDelivered {
            firstBatchDelivered = true
            let now = CFAbsoluteTimeGetCurrent()
            let message = String(
                format: "[PostgresStream] first-batch rows=%d latency=%.3fs",
                flushedCount,
                now - operationStart
            )
            logger.debug(.init(stringLiteral: message))
            print(message)
#if DEBUG
            debugLog("First batch handler rows=\(flushedCount)")
#endif
        }

#if DEBUG
        let debugTotalRowCount = totalRowCount
        let debugBatchDecodeDuration = batchDecodeDuration
        debugLog("Flush completed rows=\(flushedCount) totalRowCount=\(debugTotalRowCount) decode=\(String(format: "%.3f", debugBatchDecodeDuration)) wait=\(String(format: "%.3f", networkWait)) rampEligible=\(rampEligible)")
#endif

        await MainActor.run {
            progressHandler(update)
        }

        resetBatch()
    }

    func maybePublishProgress(throttle: TimeInterval, progressHandler: @escaping QueryProgressHandler) async {
        let now = CFAbsoluteTimeGetCurrent()
        let shouldPublishTime = (now - lastProgressPublish) >= throttle
        let shouldPublishCount = totalRowCount > lastProgressReported
        guard shouldPublishTime && shouldPublishCount else { return }
        lastProgressPublish = now
        lastProgressReported = totalRowCount

        let metrics = QueryStreamMetrics(
            batchRowCount: 0,
            loopElapsed: now - batchStartTime,
            decodeDuration: 0,
            totalElapsed: now - operationStart,
            cumulativeRowCount: totalRowCount,
            fetchRequestRowCount: nil,
            fetchRowCount: 0,
            fetchDuration: 0,
            fetchWait: 0
        )
        let update = QueryStreamUpdate(
            columns: columns,
            appendedRows: [],
            encodedRows: [],
            rawRows: [],
            totalRowCount: totalRowCount,
            metrics: metrics,
            rowRange: nil
        )
        await MainActor.run {
            progressHandler(update)
        }
    }
}

import Foundation
import PostgresKit
import PostgresWire
import Logging

extension PostgresSession {
    func streamQuery(
        sanitizedSQL: String,
        progressHandler: @escaping QueryProgressHandler,
        modeOverride: ResultStreamingExecutionMode?,
        previewLimit: Int? = nil
    ) async throws -> QueryResultSet {
        return try await streamQueryUsingSimpleProtocol(
            sanitizedSQL: sanitizedSQL,
            progressHandler: progressHandler,
            previewLimit: previewLimit
        )
    }

    func streamQueryUsingSimpleProtocol(
        sanitizedSQL: String,
        progressHandler: @escaping QueryProgressHandler,
        previewLimit: Int? = nil
    ) async throws -> QueryResultSet {
        let logger = self.logger
        let operationStart = CFAbsoluteTimeGetCurrent()

        let initialPreviewBatch = 200
        let formatter = PostgresCellFormatter()
        let formattingEnabled = (UserDefaults.standard.object(forKey: ResultFormattingEnabledDefaultsKey) as? Bool) ?? true
        let maxFlushLatency: TimeInterval = 0.015
        let batchEnqueueSize = 512

        // Use DispatchQueue.main for FIFO ordering guarantee — ensures all flush
        // callbacks are processed before the worker drain continuation resumes.
        let bridgedHandler: QueryProgressHandler = { update in
            DispatchQueue.main.async {
                progressHandler(update)
            }
        }

        return try await self.client.withConnection { connection in
            var columns: [ColumnInfo] = []
            var previewRows: [[String?]] = []
            previewRows.reserveCapacity(initialPreviewBatch)
            var totalRowCount = 0
            var firstRowLogged = false
            var worker: ResultStreamBatchWorker?
            var pendingPayloads: [ResultStreamBatchWorker.Payload] = []
            pendingPayloads.reserveCapacity(batchEnqueueSize)

            var columnCount = 0

            do {
                let rowSequence = try await connection.simpleQuery(sanitizedSQL)

                for try await row in rowSequence {
                    if Task.isCancelled {
                        throw CancellationError()
                    }

                    if columns.isEmpty {
                        let wireColumns = PostgresRowExtractor.columns(from: row)
                        columns.reserveCapacity(wireColumns.count)
                        for col in wireColumns {
                            columns.append(ColumnInfo(
                                name: col.name,
                                dataType: col.dataType,
                                isPrimaryKey: col.isPrimaryKey,
                                isNullable: col.isNullable,
                                maxLength: col.maxLength
                            ))
                        }
                        columnCount = columns.count

                        worker = ResultStreamBatchWorker(
                            label: "dk.tippr.echo.postgres.simpleStreamWorker",
                            columns: columns,
                            streamingPreviewLimit: initialPreviewBatch,
                            maxFlushLatency: maxFlushLatency,
                            operationStart: operationStart,
                            progressHandler: bridgedHandler
                        )
                    }

                    totalRowCount += 1

                    if totalRowCount <= initialPreviewBatch {
                        // Preview path: encode + format (first N rows for immediate display)
                        let (encodedData, preview) = PostgresRowExtractor.encodeBinaryRow(
                            from: row,
                            formatPreview: true,
                            formatter: formatter,
                            formattingEnabled: formattingEnabled
                        )

                        if let previewRow = preview {
                            previewRows.append(previewRow)
                        }

                        pendingPayloads.append(ResultStreamBatchWorker.Payload(
                            previewValues: preview,
                            storage: .encoded(ResultBinaryRow(data: encodedData)),
                            totalRowCount: totalRowCount,
                            decodeDuration: 0
                        ))
                    } else {
                        // Fast path: capture raw ByteBuffer slices — worker encodes on GCD queue.
                        var buffers: [NIOCore.ByteBuffer?] = []
                        var lengths: [Int] = []
                        var totalLength = 0
                        buffers.reserveCapacity(columnCount)
                        lengths.reserveCapacity(columnCount)
                        for cell in row {
                            if let bytes = cell.bytes {
                                let byteCount = bytes.readableBytes
                                buffers.append(bytes)
                                lengths.append(byteCount)
                                totalLength += 5 + byteCount
                            } else {
                                buffers.append(nil)
                                lengths.append(-1)
                                totalLength += 1
                            }
                        }

                        pendingPayloads.append(ResultStreamBatchWorker.Payload(
                            previewValues: nil,
                            storage: .raw(ResultStreamBatchWorker.RawRow(
                                buffers: buffers,
                                lengths: lengths,
                                totalLength: totalLength
                            )),
                            totalRowCount: totalRowCount,
                            decodeDuration: 0
                        ))
                    }

                    if pendingPayloads.count >= batchEnqueueSize {
                        worker?.enqueueBatch(pendingPayloads)
                        pendingPayloads.removeAll(keepingCapacity: true)
                    }

                    if !firstRowLogged {
                        firstRowLogged = true
                        let firstRowLatency = CFAbsoluteTimeGetCurrent() - operationStart
                        logger.debug("[PostgresStream] first-row latency=\(String(format: "%.3f", firstRowLatency))s")
                    }
                }
            } catch {
                throw normalizeError(error, contextSQL: sanitizedSQL)
            }

            if !pendingPayloads.isEmpty {
                worker?.enqueueBatch(pendingPayloads)
            }

            // Await worker drain: waits for the GCD queue to flush, then waits
            // for all DispatchQueue.main callbacks to execute (FIFO guarantee).
            // This ensures every row is submitted to the spool before consumeFinalResult
            // calls finalizeSpool, which would reject late-arriving batches.
            if let worker {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    worker.finish(totalRowCount: totalRowCount) {
                        DispatchQueue.main.async {
                            continuation.resume()
                        }
                    }
                }
            }

            let totalElapsed = CFAbsoluteTimeGetCurrent() - operationStart
            logger.debug("[PostgresStream] completed rows=\(totalRowCount) elapsed=\(String(format: "%.3f", totalElapsed))s previewRows=\(previewRows.count)")

            let resolvedColumns = columns.isEmpty
                ? [ColumnInfo(name: "result", dataType: "text")]
                : columns

            return QueryResultSet(
                columns: resolvedColumns,
                rows: previewRows,
                totalRowCount: totalRowCount
            )
        }
    }

}

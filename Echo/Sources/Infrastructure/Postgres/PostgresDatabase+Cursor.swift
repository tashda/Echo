import Foundation
import PostgresKit
import PostgresWire
import Logging

extension PostgresSession {
    func streamQueryUsingCursor(sanitizedSQL: String, progressHandler: @escaping QueryProgressHandler) async throws -> QueryResultSet {
        let logger = self.logger
        let operationStart = CFAbsoluteTimeGetCurrent()
        let streamingPreviewLimit = 512
        let formatterContext = CellFormatterContext()
        let formattingEnabled = (UserDefaults.standard.object(forKey: ResultFormattingEnabledDefaultsKey) as? Bool) ?? true
        let formattingModeRaw = UserDefaults.standard.string(forKey: ResultFormattingModeDefaultsKey)
        let formattingMode = ResultsFormattingMode(rawValue: formattingModeRaw ?? "") ?? .immediate

        let previewFetchSize = streamingPreviewLimit
        let storedFetchSize = UserDefaults.standard.integer(forKey: ResultStreamingFetchSizeDefaultsKey)
        let resolvedFetchSize = storedFetchSize >= 128 ? storedFetchSize : 4_096
        let configuredFetchSize = min(max(resolvedFetchSize, 128), 16_384)
        let backgroundFetchBaseline = max(streamingPreviewLimit, configuredFetchSize)
        let rampMultiplier = max(1, UserDefaults.standard.integer(forKey: ResultStreamingFetchRampMultiplierDefaultsKey))
        let rampMaxRows = max(256, UserDefaults.standard.integer(forKey: ResultStreamingFetchRampMaxDefaultsKey))
        let maxAutoFetchSize = rampMaxRows

        return try await self.client.withConnection { connection in
            let streamState = QueryStreamState(
                streamingPreviewLimit: streamingPreviewLimit,
                formatterContext: formatterContext,
                formattingEnabled: formattingEnabled,
                formattingMode: formattingMode,
                logger: logger,
                operationStart: operationStart,
                streamDebugID: nil,
                previewFetchSize: previewFetchSize,
                backgroundFetchBaseline: backgroundFetchBaseline
            )

            let cursorName = "echo_cur_" + String(UUID().uuidString.prefix(8))
            var began = false
            var declared = false
            do {
                _ = try await connection.simpleQuery("BEGIN")
                began = true
                _ = try await connection.simpleQuery("DECLARE \(cursorName) NO SCROLL CURSOR FOR \(sanitizedSQL)")
                declared = true

                var fetchSize = previewFetchSize
                var totalFetched = 0

                fetchLoop: while true {
                    let rampEligible = await streamState.totalRowCount >= streamingPreviewLimit
                    await streamState.updateFlushRequestRowCount(
                        rampMaxRows: maxAutoFetchSize,
                        backgroundFetchBaseline: backgroundFetchBaseline,
                        previewFetchSize: previewFetchSize,
                        rampEligible: rampEligible,
                        rampMultiplier: rampMultiplier
                    )
                    fetchSize = await streamState.flushRequestRowCount

                    let fetchSQL = "FETCH FORWARD \(fetchSize) FROM \(cursorName)"
                    let rows = try await connection.simpleQuery(fetchSQL)

                    var fetchedThisRound = 0
                    for try await row in rows {
                        if Task.isCancelled { throw CancellationError() }

                        let currentColumns = await streamState.columns
                        if currentColumns.isEmpty {
                            var newColumns: [ColumnInfo] = []
                            newColumns.reserveCapacity(row.count)
                            for cell in row {
                                newColumns.append(ColumnInfo(
                                    name: cell.columnName,
                                    dataType: "\(cell.dataType)",
                                    isPrimaryKey: false,
                                    isNullable: true,
                                    maxLength: nil
                                ))
                            }
                            await streamState.setColumns(newColumns)
                        }

                        let conversionStart = CFAbsoluteTimeGetCurrent()
                        var payloadCells: [ResultCellPayload] = []
                        let previewRowsNow = await streamState.previewRows
                        let isPreviewPhase: Bool = previewRowsNow.count < streamingPreviewLimit
                        let needsRawPayloadForDeferred = formattingEnabled && isPreviewPhase
                        let shouldFormatRow: Bool = formattingEnabled && isPreviewPhase

                        var formattedRow: [String?] = []
                        if shouldFormatRow { formattedRow.reserveCapacity(row.count) }

                        if shouldFormatRow || needsRawPayloadForDeferred {
                            payloadCells.reserveCapacity(row.count)
                        }

                        for cell in row {
                            if shouldFormatRow || needsRawPayloadForDeferred {
                                payloadCells.append(ResultCellPayload(cell: cell))
                            }
                            guard shouldFormatRow else { continue }
                            let displayValue: String?
                            if formattingEnabled {
                                switch formattingMode {
                                case .immediate, .deferred:
                                    displayValue = formatterContext.stringValue(for: cell)
                                }
                            } else {
                                displayValue = Self.cheapStringValue(for: cell) ?? formatterContext.stringValue(for: cell)
                            }
                            formattedRow.append(displayValue)
                        }

                        if shouldFormatRow {
                            let decodeDuration = CFAbsoluteTimeGetCurrent() - conversionStart
                            await streamState.incrementCounts(decodeDuration: decodeDuration)
                        } else {
                            await streamState.incrementTotalOnly()
                        }

                        if needsRawPayloadForDeferred {
                            await streamState.appendRawPayloadRow(ResultRowPayload(cells: payloadCells))
                        }

                        if shouldFormatRow {
                            await streamState.appendFormattedRow(formattedRow)
                            await streamState.appendEncodedRow(ResultBinaryRowCodec.encode(row: formattedRow))
                            await streamState.appendPreviewRow(formattedRow)
                        } else {
                            if needsRawPayloadForDeferred {
                                let rawCells = payloadCells.map { $0.bytes }
                                await streamState.appendEncodedRow(ResultBinaryRowCodec.encodeRaw(cells: rawCells))
                            }
                        }

                        if !(await streamState.firstRowLogged) {
                            await streamState.setFirstRowLogged()
                            let firstRowLatency = CFAbsoluteTimeGetCurrent() - operationStart
                            let message = String(format: "[PostgresStream] first-row latency=%.3fs", firstRowLatency)
                            logger.debug(.init(stringLiteral: message))
                            print(message)
                        }

                        fetchedThisRound += 1
                        totalFetched += 1

                        if await streamState.totalRowCount >= streamingPreviewLimit {
                            await streamState.maybePublishProgress(throttle: 0.12, progressHandler: progressHandler)
                        }

                        let totalRowCount = await streamState.totalRowCount
                        if totalRowCount >= streamingPreviewLimit {
                            let batchCount = await streamState.batchCount
                            let currentFlushRequestRowCount = await streamState.flushRequestRowCount
                            if batchCount >= currentFlushRequestRowCount {
                                await streamState.publishBatch(expectedRequestSize: currentFlushRequestRowCount, rampEligible: true, progressHandler: progressHandler)
                            }
                        }
                    }

                    if fetchedThisRound == 0 { break fetchLoop }

                    let remainingBatchCount = await streamState.batchCount
                    let bufferedEncoded = await streamState.encodedRows
                    let bufferedRaw = await streamState.rawPayloadRows
                    if remainingBatchCount > 0 || !bufferedEncoded.isEmpty || !bufferedRaw.isEmpty {
                        let currentFlushRequestRowCount = await streamState.flushRequestRowCount
                        let rampEligible = (await streamState.totalRowCount) > streamingPreviewLimit
                        let expectedSize: Int
                        if rampEligible {
                            expectedSize = currentFlushRequestRowCount
                        } else if remainingBatchCount > 0 {
                            expectedSize = remainingBatchCount
                        } else if !bufferedEncoded.isEmpty {
                            expectedSize = bufferedEncoded.count
                        } else {
                            expectedSize = bufferedRaw.count
                        }
                        await streamState.publishBatch(expectedRequestSize: expectedSize, rampEligible: rampEligible, progressHandler: progressHandler)
                    }
                }

                _ = try? await connection.simpleQuery("CLOSE \(cursorName)")
                declared = false
                _ = try await connection.simpleQuery("COMMIT")
                began = false

                let finalTotalRowCount = await streamState.totalRowCount
                let totalElapsed = CFAbsoluteTimeGetCurrent() - operationStart
                let completionMessage = String(format: "[PostgresStream] completed rows=%d elapsed=%.3fs", finalTotalRowCount, totalElapsed)
                logger.debug(.init(stringLiteral: completionMessage))
                print(completionMessage)

                let columnsAfterStreaming = await streamState.columns
                let resolvedColumns = columnsAfterStreaming.isEmpty
                    ? [ColumnInfo(name: "result", dataType: "text")]
                    : columnsAfterStreaming
                let previewRows = await streamState.previewRows
                let commandTag = await streamState.commandTag

                return QueryResultSet(
                    columns: resolvedColumns,
                    rows: previewRows,
                    totalRowCount: finalTotalRowCount,
                    commandTag: commandTag
                )
            } catch {
                if declared { _ = try? await connection.simpleQuery("CLOSE \(cursorName)") }
                if began { _ = try? await connection.simpleQuery("ROLLBACK") }
                throw normalizeError(error, contextSQL: sanitizedSQL)
            }
        }
    }
}

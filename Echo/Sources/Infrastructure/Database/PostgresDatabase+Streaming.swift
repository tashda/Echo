import Foundation
import PostgresKit
import PostgresWire
import Logging

extension PostgresSession {
    func streamQuery(
        sanitizedSQL: String,
        progressHandler: @escaping QueryProgressHandler,
        modeOverride: ResultStreamingExecutionMode?
    ) async throws -> QueryResultSet {
        let defaults = UserDefaults.standard

        let selectedMode: ResultStreamingExecutionMode = {
            if let modeOverride { return modeOverride }
            if let raw = defaults.string(forKey: ResultStreamingModeDefaultsKey),
               let mode = ResultStreamingExecutionMode(rawValue: raw) {
                return mode
            }
            let cursorPrefEnabled = defaults.bool(forKey: ResultStreamingUseCursorDefaultsKey)
            return cursorPrefEnabled ? .auto : .simple
        }()

        let cursorThreshold: Int? = {
            if defaults.object(forKey: ResultStreamingCursorLimitThresholdDefaultsKey) != nil {
                return max(0, defaults.integer(forKey: ResultStreamingCursorLimitThresholdDefaultsKey))
            }
            return 25_000
        }()

        let limit = simpleQueryFastPathLimit(for: sanitizedSQL)
        let threshold = cursorThreshold ?? 25_000
        let preferSimple: Bool = {
            switch selectedMode {
            case .simple: return true
            case .cursor: return false
            case .auto: return (limit != nil) && ((limit ?? 0) <= threshold)
            }
        }()

        if preferSimple {
            return try await streamQueryUsingSimpleProtocol(
                sanitizedSQL: sanitizedSQL,
                progressHandler: progressHandler
            )
        } else {
            return try await streamQueryUsingCursor(
                sanitizedSQL: sanitizedSQL,
                progressHandler: progressHandler
            )
        }
    }

    func streamQueryUsingSimpleProtocol(
        sanitizedSQL: String,
        progressHandler: @escaping QueryProgressHandler
    ) async throws -> QueryResultSet {
        let logger = self.logger
        let operationStart = CFAbsoluteTimeGetCurrent()
#if DEBUG
        let streamDebugID = String(UUID().uuidString.prefix(8))
#else
        let streamDebugID: String? = nil
#endif

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

        return try await self.client.withConnection { connection in
            let streamState = QueryStreamState(
                streamingPreviewLimit: streamingPreviewLimit,
                formatterContext: formatterContext,
                formattingEnabled: formattingEnabled,
                formattingMode: formattingMode,
                logger: logger,
                operationStart: operationStart,
                streamDebugID: streamDebugID,
                previewFetchSize: previewFetchSize,
                backgroundFetchBaseline: backgroundFetchBaseline
            )

            do {
                let rowSequence = try await connection.simpleQuery(sanitizedSQL)

                for try await row in rowSequence {
                    if Task.isCancelled {
                        throw CancellationError()
                    }

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
                    let isPreviewPhase = previewRowsNow.count < streamingPreviewLimit
                    let shouldFormatRow: Bool = formattingEnabled && isPreviewPhase
                    let needsRawPayloadForDeferred: Bool = formattingEnabled && isPreviewPhase

                    var formattedRow: [String?] = []
                    if shouldFormatRow {
                        formattedRow.reserveCapacity(row.count)
                    }

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

                    let firstRowLogged = await streamState.firstRowLogged
                    if !firstRowLogged {
                        await streamState.setFirstRowLogged()
                        let firstRowLatency = CFAbsoluteTimeGetCurrent() - operationStart
                        let message = String(
                            format: "[PostgresStream] first-row latency=%.3fs",
                            firstRowLatency
                        )
                        logger.debug(.init(stringLiteral: message))
                        print(message)
                    }

                    let totalRowCount = await streamState.totalRowCount
                    if totalRowCount < streamingPreviewLimit {
                        continue
                    }

                    let batchCount = await streamState.batchCount
                    if totalRowCount == streamingPreviewLimit {
                        await streamState.publishBatch(expectedRequestSize: batchCount, rampEligible: false, progressHandler: progressHandler)
                        continue
                    }

                    await streamState.maybePublishProgress(throttle: 0.12, progressHandler: progressHandler)
                }
            } catch {
                throw normalizeError(error, contextSQL: sanitizedSQL)
            }

            let remainingBatchCount = await streamState.batchCount
            if remainingBatchCount > 0 {
                await streamState.publishBatch(expectedRequestSize: remainingBatchCount, rampEligible: false, progressHandler: progressHandler)
            }

            let finalTotalRowCount = await streamState.totalRowCount
            let totalElapsed = CFAbsoluteTimeGetCurrent() - operationStart
            let completionMessage = String(
                format: "[PostgresStream] completed rows=%d elapsed=%.3fs",
                finalTotalRowCount,
                totalElapsed
            )
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
        }
    }
}

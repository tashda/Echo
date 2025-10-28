import Foundation
import os.signpost
import os.log
import NIOCore
import NIOFoundationCompat
import PostgresKit
import Logging

typealias PostgresQueryResult = PostgresRowSequence

private let postgresFetchLog = OSLog(subsystem: "dk.tippr.echo", category: .pointsOfInterest)

private extension ResultCellPayload {
    nonisolated init(cell: PostgresCell) {
        let formatRaw = UInt8(clamping: cell.format.rawValue)
        let format = ResultCellPayload.Format(rawValue: formatRaw) ?? .text

        let data: Data?
        if var buffer = cell.bytes {
            let readable = buffer.readableBytes
            if readable > 0 {
                if let extracted = buffer.readData(length: readable) {
                    data = extracted
                } else if let bytes = buffer.readBytes(length: readable) {
                    data = Data(bytes)
                } else {
                    data = Data()
                }
            } else {
                data = Data()
            }
        } else {
            data = nil
        }

        self.init(dataTypeOID: cell.dataType.rawValue, format: format, bytes: data)
    }
}

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

    init(streamingPreviewLimit: Int, formatterContext: CellFormatterContext, formattingEnabled: Bool, formattingMode: ResultsFormattingMode, logger: Logger, operationStart: CFAbsoluteTime, streamDebugID: String?, previewFetchSize: Int, backgroundFetchBaseline: Int) {
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
            // Ensure we elevate to at least the baseline once the preview is complete
            if dynamicBackgroundFlushSize < backgroundFetchBaseline {
                dynamicBackgroundFlushSize = backgroundFetchBaseline
            }

            // Aggressively ramp up to reduce round-trips, respecting a ceiling.
            // Previous logic keyed off `batchCount >= flushRequestRowCount`, which typically
            // resets to 0 after a flush and prevented any ramping beyond the baseline.
            // Here we ramp as soon as we are eligible (i.e., after preview) and below the cap.
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
            // Still in preview window; keep small request size for interactivity
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

    /// Publish a lightweight progress-only update (no rows), throttled by time.
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

struct PostgresNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.postgres")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration
    ) async throws -> DatabaseSession {
        guard authentication.method == .sqlPassword else {
            throw DatabaseError.authenticationFailed("Windows authentication is not supported for PostgreSQL")
        }
        // PostgreSQL requires a database name, default to "postgres" if none specified
        let effectiveDatabase = (database?.isEmpty == false) ? database : "postgres"
        let databaseLabel = effectiveDatabase ?? "postgres"
        logger.info("Connecting to PostgreSQL at \(host):\(port)/\(databaseLabel)")

        let configuration = PostgresConfiguration(
            host: host,
            port: port,
            database: effectiveDatabase ?? "postgres",
            username: authentication.username,
            password: authentication.password,
            useTLS: tls,
            applicationName: "Echo"
        )

        let client = try await PostgresDatabaseClient.connect(configuration: configuration, logger: logger)

        return PostgresSession(client: client, logger: logger)
    }
}

extension PostgresSession: @unchecked Sendable {}

final class PostgresSession: DatabaseSession {
    private let client: PostgresDatabaseClient
    private let logger: Logger

    init(client: PostgresDatabaseClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    func close() async {
        client.close()
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if let progressHandler {
            let sanitized = sanitizeSQL(sql)
            return try await streamQuery(sanitizedSQL: sanitized, progressHandler: progressHandler, modeOverride: nil)
        } else {
            return try await executeSimpleQuery(sql)
        }
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if let progressHandler {
            let sanitized = sanitizeSQL(sql)
            return try await streamQuery(sanitizedSQL: sanitized, progressHandler: progressHandler, modeOverride: executionMode)
        } else {
            return try await executeSimpleQuery(sql)
        }
    }

    private func executeSimpleQuery(_ sql: String) async throws -> QueryResultSet {
        do {
            let result = try await client.simpleQuery(sql)

            var columns: [ColumnInfo] = []
            var rows: [[String?]] = []
            rows.reserveCapacity(512)

            let formatterContext = CellFormatterContext()

            for try await row in result {
                if columns.isEmpty {
                    for cell in row {
                        columns.append(ColumnInfo(
                            name: cell.columnName,
                            dataType: "\(cell.dataType)",
                            isPrimaryKey: false,
                            isNullable: true,
                            maxLength: nil
                        ))
                    }
                }

                var rowValues: [String?] = []
                rowValues.reserveCapacity(row.count)
                for cell in row {
                    rowValues.append(formatterContext.stringValue(for: cell))
                }
                rows.append(rowValues)
            }

            #if DEBUG
            print("[PostgresStream] simpleQuery fetched \(rows.count) rows")
            #endif

            let resolvedColumns = columns.isEmpty
                ? [ColumnInfo(name: "result", dataType: "text")]
                : columns

            return QueryResultSet(
                columns: resolvedColumns,
                rows: rows
            )
        } catch {
            throw normalizeError(error, contextSQL: sql)
        }
    }

    private func streamQuery(
        sanitizedSQL: String,
        progressHandler: @escaping QueryProgressHandler,
        modeOverride: ResultStreamingExecutionMode?
    ) async throws -> QueryResultSet {
        let defaults = UserDefaults.standard
        // Determine execution mode: override > stored mode > legacy toggle
        let selectedMode: ResultStreamingExecutionMode = {
            if let modeOverride { return modeOverride }
            if let raw = defaults.string(forKey: ResultStreamingModeDefaultsKey),
               let mode = ResultStreamingExecutionMode(rawValue: raw) {
                return mode
            }
            // Legacy fallback: toggle implies .auto or .simple
            let cursorPrefEnabled = defaults.bool(forKey: ResultStreamingUseCursorDefaultsKey)
            return cursorPrefEnabled ? .auto : .simple
        }()

        let useCursorStreaming: Bool = {
            switch selectedMode {
            case .simple:
                return false
            case .cursor:
                return true
            case .auto:
                let limit = simpleQueryFastPathLimit(for: sanitizedSQL)
                let thresholdKey = ResultStreamingCursorLimitThresholdDefaultsKey
                let threshold: Int = (defaults.object(forKey: thresholdKey) != nil)
                    ? max(0, defaults.integer(forKey: thresholdKey))
                    : 25_000
                return (limit == nil) || ((limit ?? 0) > threshold)
            }
        }()

        if useCursorStreaming {
            return try await streamQueryUsingCursor(
                sanitizedSQL: sanitizedSQL,
                progressHandler: progressHandler
            )
        } else {
            return try await streamQueryUsingSimpleProtocol(
                sanitizedSQL: sanitizedSQL,
                progressHandler: progressHandler
            )
        }
    }

    private func streamQueryUsingCursor(sanitizedSQL: String, progressHandler: @escaping QueryProgressHandler) async throws -> QueryResultSet {
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
                    // Adjust dynamic fetch size based on prior throughput
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
                        // Prefer preview-first: format rows only until preview limit.
                        // Background rows are deferred for performance regardless of global setting.
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
                            // Count background rows without incurring decode costs.
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
                            } else {
                                // Skip building encoded rows for background to keep CPU minimal.
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

                        // Throttle progress-only updates so row counter advances smoothly without UI cost.
                        if await streamState.totalRowCount >= streamingPreviewLimit {
                            await streamState.maybePublishProgress(throttle: 0.12, progressHandler: progressHandler)
                        }

                        let totalRowCount = await streamState.totalRowCount
                        if totalRowCount >= streamingPreviewLimit {
                            // Publish batches opportunistically during long fetches
                            let batchCount = await streamState.batchCount
                            let flushRequestRowCount = await streamState.flushRequestRowCount
                            if batchCount >= flushRequestRowCount {
                                await streamState.publishBatch(expectedRequestSize: flushRequestRowCount, rampEligible: true, progressHandler: progressHandler)
                            }
                        }
                    }

                    if fetchedThisRound == 0 { break fetchLoop }

                    // Flush any partial batch or buffered encoded rows between fetches to keep UI snappy
                    let remainingBatchCount = await streamState.batchCount
                    let bufferedEncoded = await streamState.encodedRows
                    let bufferedRaw = await streamState.rawPayloadRows
                    if remainingBatchCount > 0 || !bufferedEncoded.isEmpty || !bufferedRaw.isEmpty {
                        let flushRequestRowCount = await streamState.flushRequestRowCount
                        let rampEligible = (await streamState.totalRowCount) > streamingPreviewLimit
                        let expectedSize: Int
                        if rampEligible {
                            expectedSize = flushRequestRowCount
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

    private func streamQueryUsingSimpleProtocol(
        sanitizedSQL: String,
        progressHandler: @escaping QueryProgressHandler
    ) async throws -> QueryResultSet {
        let logger = self.logger
        let operationStart = CFAbsoluteTimeGetCurrent()
#if DEBUG
        let streamDebugID = String(UUID().uuidString.prefix(8))
        func debugLog(_ message: @autoclosure () -> String) {
            let elapsed = CFAbsoluteTimeGetCurrent() - operationStart
            print("[PostgresStream][\(streamDebugID)] t=\(String(format: "%.3f", elapsed)) \(message())")
        }
#else
        func debugLog(_ message: @autoclosure () -> String) {}
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

        // Note: simple protocol path does not use ramp ceilings

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
                    // Prefer preview-first: only format rows until the preview is filled; background is deferred for speed.
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
                        } else {
                            // In simple mode, skip building encoded rows for background to keep CPU minimal.
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

                    // Keep the UI counter lively during long simple-protocol streams without forcing heavy UI merges
                    await streamState.maybePublishProgress(throttle: 0.12, progressHandler: progressHandler)

                    // Skip interim timed/threshold flushes in simple mode to minimize UI churn; rely on
                    // preview flush above and a single final flush below.
                }

                // await streamState.setCommandTag(rowSequence.commandTag)
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
#if DEBUG
            await streamState.debugLog("Streaming complete totalRows=\(finalTotalRowCount)")
#endif

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

    @Sendable
    private nonisolated static func cheapStringValue(for cell: PostgresCell) -> String? {
        if cell.format == .text, let buffer = cell.bytes {
            let readable = buffer.readableBytes
            guard readable > 0 else { return "" }
            return buffer.getString(at: buffer.readerIndex, length: readable)
        }
        if let decoded = try? cell.decode(String.self, context: .default) {
            return decoded
        }
        if var buffer = cell.bytes {
            let readable = buffer.readableBytes
            guard readable > 0 else { return "" }
            if let string = buffer.getString(at: buffer.readerIndex, length: readable) {
                return string
            }
            if let bytes = buffer.readBytes(length: readable) {
                return bytes.reduce(into: "0x") { result, byte in
                    result.append(String(format: "%02X", byte))
                }
            }
        }
        return nil
    }

    private func simpleQueryFastPathLimit(for sql: String) -> Int? {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedPrefix = trimmed.lowercased()
        guard normalizedPrefix.hasPrefix("select") || normalizedPrefix.hasPrefix("with ") else { return nil }

        let pattern = #"(?i)\blimit\s+(\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              match.numberOfRanges > 1,
              let bound = Range(match.range(at: 1), in: trimmed),
              let value = Int(trimmed[bound]) else {
            return nil
        }
        return value
    }

    private func sanitizeSQL(_ sql: String) -> String {
        var trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.last == ";" {
            trimmed.removeLast()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func normalizeError(_ error: Error, contextSQL: String? = nil) -> Error {
        guard let pgError = error as? PSQLError else { return error }

        var lines: [String] = []
        if let message = pgError.serverInfo?[.message], !message.isEmpty {
            lines.append(message)
        } else {
            lines.append(pgError.localizedDescription)
        }
        if let detail = pgError.serverInfo?[.detail], !detail.isEmpty {
            lines.append(detail)
        }
        if let hint = pgError.serverInfo?[.hint], !hint.isEmpty {
            lines.append("Hint: \(hint)")
        }
        if let sqlState = pgError.serverInfo?[.sqlState], !sqlState.isEmpty {
            lines.append("SQLSTATE: \(sqlState)")
        }
        if
            let positionString = pgError.serverInfo?[.position],
            let position = Int(positionString),
            position > 0,
            let sql = contextSQL
        {
            let limitedSQL = sql.prefix(2_000)
            lines.append(String(limitedSQL))
            let caretPosition = min(position - 1, limitedSQL.count - 1)
            let pointer = String(repeating: " ", count: max(0, caretPosition)) + "^"
            lines.append(pointer)
        }

        let message = lines.joined(separator: "\n")
        logger.error(.init(stringLiteral: "PostgreSQL error: \(message)"))
        return DatabaseError.queryError(message)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let pagedSQL = "\(sql) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let result = try await client.simpleQuery(sql)
        var count = 0
        for try await _ in result { count += 1 }
        return count
    }

    func listDatabases() async throws -> [String] {
        let meta = PostgresMetadata()
        return try await meta.listDatabases(using: client)
    }

    func listSchemas() async throws -> [String] {
        let meta = PostgresMetadata()
        return try await meta.listSchemas(using: client)
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName = schema ?? "public"
        return try await loadSchemaInfo(schemaName, progress: nil).objects
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName ?? "public"
        let meta = PostgresMetadata()
        let cols = try await meta.listColumns(using: client, schema: schema, table: tableName)
        return cols.map { ColumnInfo(name: $0.name, dataType: $0.dataType, isPrimaryKey: false, isNullable: $0.isNullable, maxLength: nil) }
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let meta = PostgresMetadata()
        async let cols: [TableStructureDetails.Column] = {
            let list = try? await meta.listColumns(using: client, schema: schema, table: table)
            return (list ?? []).map { TableStructureDetails.Column(name: $0.name, dataType: $0.dataType, isNullable: $0.isNullable, defaultValue: $0.defaultValue, generatedExpression: nil) }
        }()
        async let pk: TableStructureDetails.PrimaryKey? = {
            if let p = try? await meta.primaryKey(using: client, schema: schema, table: table) {
                return TableStructureDetails.PrimaryKey(name: p.name, columns: p.columns)
            }
            return nil
        }()
        async let idx: [TableStructureDetails.Index] = {
            let list = try? await meta.listIndexes(using: client, schema: schema, table: table)
            return (list ?? []).map { i in
                let columns = i.columns.enumerated().map { (pos, c) in
                    TableStructureDetails.Index.Column(name: c.name, position: pos + 1, sortOrder: c.isDescending ? .descending : .ascending)
                }
                return TableStructureDetails.Index(name: i.name, columns: columns, isUnique: i.isUnique, filterCondition: i.predicate)
            }
        }()
        async let fks: [TableStructureDetails.ForeignKey] = {
            let list = try? await meta.foreignKeys(using: client, schema: schema, table: table)
            return (list ?? []).map { fk in
                TableStructureDetails.ForeignKey(name: fk.name, columns: fk.columns, referencedSchema: fk.referencedSchema, referencedTable: fk.referencedTable, referencedColumns: fk.referencedColumns, onUpdate: fk.onUpdate, onDelete: fk.onDelete)
            }
        }()
        async let uniques: [TableStructureDetails.UniqueConstraint] = {
            let list = try? await meta.uniqueConstraints(using: client, schema: schema, table: table)
            return (list ?? []).map { TableStructureDetails.UniqueConstraint(name: $0.name, columns: $0.columns) }
        }()
        async let deps: [TableStructureDetails.Dependency] = {
            let list = try? await meta.dependencies(using: client, schema: schema, table: table)
            return (list ?? []).map { d in
                TableStructureDetails.Dependency(name: d.name, baseColumns: d.referencingColumns, referencedTable: d.sourceTable, referencedColumns: d.referencedColumns, onUpdate: d.onUpdate, onDelete: d.onDelete)
            }
        }()
        let (columns, primaryKey, indexes, foreignKeys, uniqueConstraints, dependencies) = await (cols, pk, idx, fks, uniques, deps)
        return TableStructureDetails(columns: columns, primaryKey: primaryKey, indexes: indexes, uniqueConstraints: uniqueConstraints, foreignKeys: foreignKeys, dependencies: dependencies)
    }

    private func fetchColumnsByObject(schemaName: String) async throws -> [String: [ColumnInfo]] {
        let meta = PostgresMetadata()
        let details = try await meta.columnsByTable(using: client, schema: schemaName)
        var result: [String: [ColumnInfo]] = [:]
        for (table, cols) in details {
            result[table] = cols.map { d in
                let fk: ColumnInfo.ForeignKeyReference? = d.foreignKey.map { ref in
                    ColumnInfo.ForeignKeyReference(
                        constraintName: ref.constraintName,
                        referencedSchema: ref.referencedSchema,
                        referencedTable: ref.referencedTable,
                        referencedColumn: ref.referencedColumn
                    )
                }
                return ColumnInfo(
                    name: d.name,
                    dataType: d.dataType,
                    isPrimaryKey: d.isPrimaryKey,
                    isNullable: d.isNullable,
                    maxLength: d.maxLength,
                    foreignKey: fk
                )
            }
        }
        return result
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        switch objectType {
        case .table, .materializedView:
            let columns = try await getTableSchema(objectName, schemaName: schemaName)
            guard !columns.isEmpty else {
                return "-- No columns available for \(schemaName).\(objectName)"
            }

            let columnLines = columns.map { column -> String in
                var parts = ["\"\(column.name)\" \(column.dataType)"]
                if let maxLength = column.maxLength, maxLength > 0 {
                    parts[0] += "(\(maxLength))"
                }
                if !column.isNullable {
                    parts.append("NOT NULL")
                }
                if column.isPrimaryKey {
                    parts.append("PRIMARY KEY")
                }
                return parts.joined(separator: " ")
            }

            let keyword = objectType == .table ? "TABLE" : "MATERIALIZED VIEW"
            return """
            CREATE \(keyword) "\(schemaName)"."\(objectName)" (
            \(columnLines.joined(separator: ",\n"))
            );
            """

        case .view:
            let meta = PostgresMetadata()
            if let definition = try await meta.viewDefinition(using: client, schema: schemaName, view: objectName) {
                return definition
            }
            return "-- View definition unavailable"

        case .function, .procedure:
            let meta = PostgresMetadata()
            if let definition = try await meta.functionDefinition(using: client, schema: schemaName, name: objectName) {
                return definition
            }
            let descriptor = objectType == .function ? "Function" : "Procedure"
            return "-- \(descriptor) definition unavailable"

        case .trigger:
            let meta = PostgresMetadata()
            if let definition = try await meta.triggerDefinition(using: client, schema: schemaName, name: objectName) {
                return definition
            }
            return "-- Trigger definition unavailable"
        }
    }

    // MARK: - Helpers

    private func performQuery(_ sql: String, binds: [PostgresData] = []) async throws -> PostgresRowSequence {
        try await client.withConnection { conn in
            try await conn.query(sql, binds: binds)
        }
    }

    private func firstString(_ sql: String, binds: [PostgresData]) async throws -> String? {
        let result = try await performQuery(sql, binds: binds)
        for try await value in result.decode(String?.self) {
            if let value {
                return value
            }
        }
        return nil
    }
}

struct CellFormatterContext: Sendable {
    nonisolated private static let postgresEpoch: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2000
        components.month = 1
        components.day = 1
        return components.date!
    }()
    
    nonisolated private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    
    nonisolated private static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }
    
    nonisolated func stringValue(for cell: PostgresCell) -> String? {
        guard let buffer = cell.bytes else { return nil }
        
        if cell.format == .text {
            let readableBytes = buffer.readableBytes
            guard readableBytes > 0 else { return "" }
            let raw = buffer.getString(at: buffer.readerIndex, length: readableBytes) ?? ""
            if cell.dataType == .bool {
                if raw == "t" { return "true" }
                if raw == "f" { return "false" }
            }
            return raw
        }
        
        switch cell.dataType {
        case .bool:
            if let value = try? cell.decode(Bool.self) {
                return value ? "true" : "false"
            }
        case .int2:
            return integerString(from: cell, as: Int16.self)
        case .int4:
            return integerString(from: cell, as: Int32.self)
        case .int8:
            return integerString(from: cell, as: Int64.self)
        case .float4:
            if let value = try? cell.decode(Float.self) {
                return String(value)
            }
        case .float8:
            if let value = try? cell.decode(Double.self) {
                return String(value)
            }
        case .numeric, .money:
            if let decimalValue = try? cell.decode(Decimal.self, context: .default) {
                return NSDecimalNumber(decimal: decimalValue).stringValue
            }
        case .json, .jsonb:
            if let string = try? cell.decode(String.self, context: .default) {
                return string
            }
        case .bytea:
            if var mutableBuffer = cell.bytes {
                return hexString(from: &mutableBuffer)
            }
        case .timestamp:
            if var mutableBuffer = cell.bytes,
               let microseconds: Int64 = mutableBuffer.readInteger(as: Int64.self) {
                return formatTimestamp(microseconds: microseconds)
            }
        case .timestamptz:
            if var mutableBuffer = cell.bytes,
               let microseconds: Int64 = mutableBuffer.readInteger(as: Int64.self) {
                return formatTimestampWithTimeZone(microseconds: microseconds)
            }
        case .date:
            if var mutableBuffer = cell.bytes,
               let days: Int32 = mutableBuffer.readInteger(as: Int32.self) {
                return formatDate(days: Int(days))
            }
        case .time:
            if var mutableBuffer = cell.bytes,
               let microseconds: Int64 = mutableBuffer.readInteger(as: Int64.self) {
                return formatTime(microseconds: microseconds)
            }
        case .timetz:
            if var mutableBuffer = cell.bytes,
               let microseconds: Int64 = mutableBuffer.readInteger(as: Int64.self),
               let tzOffset: Int32 = mutableBuffer.readInteger(as: Int32.self) {
                return formatTimeWithTimeZone(microseconds: microseconds, offsetMinutesWest: Int(tzOffset))
            }
        default:
            if let string = try? cell.decode(String.self, context: .default) {
                return string
            }
        }
        
        if var mutableBuffer = cell.bytes {
            return hexString(from: &mutableBuffer)
        }
        return nil
    }
    
    private nonisolated func integerString<Integer>(from cell: PostgresCell, as type: Integer.Type) -> String?
    where Integer: FixedWidthInteger & PostgresDecodable {
        guard let value = try? cell.decode(type, context: .default) else { return nil }
        return String(value)
    }
    
    private nonisolated func hexString(from buffer: inout ByteBuffer) -> String {
        let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    
    private nonisolated func formatTimestamp(microseconds: Int64) -> String {
        let (seconds, microsRemainder) = Self.splitMicroseconds(microseconds)
        let date = Date(timeInterval: TimeInterval(seconds), since: Self.postgresEpoch)
        let calendar = Self.utcCalendar
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day,
            let hour = components.hour,
            let minute = components.minute,
            let second = components.second
        else {
            return ""
        }
        let fractional = formatFractionalMicroseconds(microsRemainder)
        return String(format: "%04d-%02d-%02d %02d:%02d:%02d%@", year, month, day, hour, minute, second, fractional)
    }
    
    private nonisolated func formatTimestampWithTimeZone(microseconds: Int64) -> String {
        let (seconds, microsRemainder) = Self.splitMicroseconds(microseconds)
        let date = Date(timeInterval: TimeInterval(seconds), since: Self.postgresEpoch)
        let calendar = Self.localCalendar
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day,
            let hour = components.hour,
            let minute = components.minute,
            let second = components.second
        else {
            return ""
        }
        let fractional = formatFractionalMicroseconds(microsRemainder)
        let timeZone = components.timeZone ?? TimeZone.current
        let offsetSeconds = timeZone.secondsFromGMT(for: date)
        let offsetSign = offsetSeconds >= 0 ? "+" : "-"
        let offset = abs(offsetSeconds)
        let offsetHours = offset / 3600
        let offsetMinutes = (offset % 3600) / 60
        return String(
            format: "%04d-%02d-%02d %02d:%02d:%02d%@%@%02d:%02d",
            year,
            month,
            day,
            hour,
            minute,
            second,
            fractional,
            offsetSign,
            offsetHours,
            offsetMinutes
        )
    }
    
    private nonisolated func formatDate(days: Int) -> String {
        if let date = Self.utcCalendar.date(byAdding: .day, value: days, to: Self.postgresEpoch) {
            let components = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
            if let year = components.year, let month = components.month, let day = components.day {
                return String(format: "%04d-%02d-%02d", year, month, day)
            }
        }
        return ""
    }
    
    private nonisolated func formatTime(microseconds: Int64) -> String {
        let (seconds, microsRemainder) = Self.splitMicroseconds(microseconds)
        let normalizedSeconds = ((seconds % 86_400) + 86_400) % 86_400
        let hour = normalizedSeconds / 3_600
        let minute = (normalizedSeconds % 3_600) / 60
        let second = normalizedSeconds % 60
        let fractional = formatFractionalMicroseconds(microsRemainder)
        return String(format: "%02d:%02d:%02d%@", hour, minute, second, fractional)
    }
    
    private nonisolated func formatTimeWithTimeZone(microseconds: Int64, offsetMinutesWest: Int) -> String {
        let timeString = formatTime(microseconds: microseconds)
        let minutesEast = -offsetMinutesWest
        let sign = minutesEast >= 0 ? "+" : "-"
        let absoluteMinutes = abs(minutesEast)
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        return String(format: "%@%@%02d:%02d", timeString, sign, hours, minutes)
    }
    
    nonisolated private static func splitMicroseconds(_ value: Int64) -> (seconds: Int64, remainder: Int64) {
        var seconds = value / 1_000_000
        var remainder = value % 1_000_000
        if remainder < 0 {
            remainder += 1_000_000
            seconds -= 1
        }
        return (seconds, remainder)
    }
    
    private nonisolated func formatFractionalMicroseconds(_ value: Int64) -> String {
        guard value != 0 else { return "" }
        var fractional = String(format: "%06lld", value)
        while fractional.last == "0" {
            fractional.removeLast()
        }
        return "." + fractional
    }
}

extension PostgresSession: DatabaseMetadataSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let meta = PostgresMetadata()
        let summary = try await meta.schemaSummary(using: client, schema: schemaName) { type, current, total in
            if let progress {
                let mapped: SchemaObjectInfo.ObjectType
                switch type {
                case .table: mapped = .table
                case .view: mapped = .view
                case .materializedView: mapped = .materializedView
                case .function: mapped = .function
                case .trigger: mapped = .trigger
                }
                await progress(mapped, current, total)
            }
        }

        var objects: [SchemaObjectInfo] = []
        for o in summary.objects {
            let columns: [ColumnInfo] = o.columns.map { d in
                let fk: ColumnInfo.ForeignKeyReference? = d.foreignKey.map { ref in
                    ColumnInfo.ForeignKeyReference(
                        constraintName: ref.constraintName,
                        referencedSchema: ref.referencedSchema,
                        referencedTable: ref.referencedTable,
                        referencedColumn: ref.referencedColumn
                    )
                }
                return ColumnInfo(name: d.name, dataType: d.dataType, isPrimaryKey: d.isPrimaryKey, isNullable: d.isNullable, maxLength: d.maxLength, foreignKey: fk)
            }

            let mapped: SchemaObjectInfo.ObjectType
            switch o.type {
            case .table: mapped = .table
            case .view: mapped = .view
            case .materializedView: mapped = .materializedView
            case .function: mapped = .function
            case .trigger: mapped = .trigger
            }

            objects.append(SchemaObjectInfo(
                name: o.name,
                schema: summary.schema,
                type: mapped,
                columns: columns,
                triggerAction: o.triggerAction,
                triggerTable: o.triggerTable
            ))
        }

        return SchemaInfo(name: schemaName, objects: objects)
    }
}

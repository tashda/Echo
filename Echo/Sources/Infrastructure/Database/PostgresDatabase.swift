import Foundation
import os.signpost
import os.log
import NIOCore
import NIOFoundationCompat
import PostgresNIO
import Logging

typealias PostgresQueryResult = PostgresRowSequence

private let postgresFetchLog = OSLog(subsystem: "dk.tippr.echo", category: .pointsOfInterest)

private extension ResultCellPayload {
    init(cell: PostgresCell) {
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

        let configuration = PostgresClient.Configuration(
            host: host,
            port: port,
            username: authentication.username,
            password: authentication.password,
            database: effectiveDatabase,
            tls: tls ? .require(.makeClientConfiguration()) : .disable
        )

        let client = PostgresClient(configuration: configuration, backgroundLogger: logger)
        let clientTask = Task {
            await client.run()
        }

        // Ensure the run loop has started before leasing connections to avoid warnings from PostgresNIO
        await Task.yield()

        do {
            _ = try await client.query("SELECT 1", logger: logger)
        } catch {
            clientTask.cancel()
            throw DatabaseError.connectionFailed("Failed to connect: \(error.localizedDescription)")
        }

        return PostgresSession(client: client, clientTask: clientTask, logger: logger)
    }
}

extension PostgresSession: @unchecked Sendable {}

final class PostgresSession: DatabaseSession {
    private let client: PostgresClient
    private let clientTask: Task<Void, Never>
    private let logger: Logger

    init(client: PostgresClient, clientTask: Task<Void, Never>, logger: Logger) {
        self.client = client
        self.clientTask = clientTask
        self.logger = logger
    }

    func close() async {
        clientTask.cancel()
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if let progressHandler {
            let sanitized = sanitizeSQL(sql)
            return try await streamQuery(sanitizedSQL: sanitized, progressHandler: progressHandler)
        } else {
            return try await executeSimpleQuery(sql)
        }
    }

    private func executeSimpleQuery(_ sql: String) async throws -> QueryResultSet {
        let query = PostgresQuery(unsafeSQL: sql)
        do {
            let result = try await client.query(query, logger: logger)

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
        progressHandler: @escaping QueryProgressHandler
    ) async throws -> QueryResultSet {
        let defaults = UserDefaults.standard
        let hasExplicitCursorPreference = defaults.object(forKey: ResultStreamingUseCursorDefaultsKey) != nil
        let useCursorStreaming: Bool
        if hasExplicitCursorPreference {
            useCursorStreaming = defaults.bool(forKey: ResultStreamingUseCursorDefaultsKey)
        } else {
            useCursorStreaming = false
        }

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
#if DEBUG
        let streamDebugID = String(UUID().uuidString.prefix(8))
        func debugLog(_ message: @autoclosure () -> String) {
            let elapsed = CFAbsoluteTimeGetCurrent() - operationStart
            print("[PostgresStream][\(streamDebugID)] t=\(String(format: "%.3f", elapsed)) \(message())")
        }
#else
        func debugLog(_ message: @autoclosure () -> String) {}
#endif
        var columns: [ColumnInfo] = []
        let streamingPreviewLimit = 512
        let formatterContext = CellFormatterContext()
        let formattingEnabled = (UserDefaults.standard.object(forKey: ResultFormattingEnabledDefaultsKey) as? Bool) ?? true
        let formattingModeRaw = UserDefaults.standard.string(forKey: ResultFormattingModeDefaultsKey)
        let formattingMode = ResultsFormattingMode(rawValue: formattingModeRaw ?? "") ?? .immediate
        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(streamingPreviewLimit)
        var totalRowCount = 0
        var firstBatchDelivered = false
        var firstRowLogged = false

        func executeVoidStatement(_ sql: String) async throws {
            let statement = PostgresQuery(unsafeSQL: sql)
            do {
                let result = try await client.query(statement, logger: logger)
                for try await _ in result {}
            } catch {
                throw normalizeError(error, contextSQL: sql)
            }
        }

        let cursorName = "echo_cursor_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let previewFetchSize = streamingPreviewLimit
        let storedFetchSize = UserDefaults.standard.integer(forKey: ResultStreamingFetchSizeDefaultsKey)
        let resolvedFetchSize = storedFetchSize >= 128 ? storedFetchSize : 4_096
        let configuredFetchSize = min(max(resolvedFetchSize, 128), 16_384)
        let backgroundFetchBaseline = max(streamingPreviewLimit, configuredFetchSize)

        let storedRampMultiplier = UserDefaults.standard.integer(forKey: ResultStreamingFetchRampMultiplierDefaultsKey)
        let resolvedRampMultiplier = storedRampMultiplier >= 1 ? storedRampMultiplier : 12
        let rampMultiplier = min(max(resolvedRampMultiplier, 1), 64)

        let storedRampMax = UserDefaults.standard.integer(forKey: ResultStreamingFetchRampMaxDefaultsKey)
        let resolvedRampMax = storedRampMax >= 256 ? storedRampMax : 524_288
        let rampCeiling = max(backgroundFetchBaseline, min(resolvedRampMax, 1_048_576))
        let maxAutoFetchSize = min(rampCeiling, 262_144)

        var dynamicBackgroundFetchSize = backgroundFetchBaseline
        let rampedBaselineForTotal: (Int) -> Int = { totalCount in
            guard totalCount >= streamingPreviewLimit else {
                return backgroundFetchBaseline
            }
            let stage = max(Double(totalCount) / Double(streamingPreviewLimit), 1.0)
            let factor = min(Double(rampMultiplier), max(1.0, sqrt(stage)))
            let scaled = Int(Double(backgroundFetchBaseline) * factor)
            return min(max(backgroundFetchBaseline, scaled), rampCeiling)
        }

        let client = self.client

        var transactionBegan = false
        var cursorActive = false

        debugLog("BEGIN transaction")
        try await executeVoidStatement("BEGIN")
        transactionBegan = true

        do {
            try Task.checkCancellation()

            let declareSQL = "DECLARE \(cursorName) CURSOR FOR \(sanitizedSQL)"
            try await executeVoidStatement(declareSQL)
            debugLog("Declared cursor \(cursorName) for sanitized SQL (length=\(sanitizedSQL.count))")
            cursorActive = true

            let readyTimestamp = CFAbsoluteTimeGetCurrent()
            let readyMessage = String(
                format: "[PostgresStream] sequence-ready latency=%.3fs",
                readyTimestamp - operationStart
            )
            logger.debug(.init(stringLiteral: readyMessage))
            print(readyMessage)

            var fetchSize = previewFetchSize
            debugLog("Fetch loop start initial fetchSize=\(fetchSize)")

            fetchLoop: while true {
                try Task.checkCancellation()

                os_log("FetchBatch begin rows=%{public}d", log: postgresFetchLog, type: .info, fetchSize)
                print("[Signpost] FetchBatch begin rows=\(fetchSize)")
                if #available(macOS 10.14, *) {
                    os_signpost(.begin, log: postgresFetchLog, name: "FetchBatch", "%{public}d rows", fetchSize)
                }
                let fetchStart = CFAbsoluteTimeGetCurrent()
                let fetchSQL = "FETCH FORWARD \(fetchSize) FROM \(cursorName)"
                let fetchQuery = PostgresQuery(unsafeSQL: fetchSQL)
#if DEBUG
                debugLog("Issuing fetch size=\(fetchSize) currentTotal=\(totalRowCount)")
#endif
                var optionalSequence: PostgresRowSequence?
                do {
                    optionalSequence = try await client.query(fetchQuery, logger: logger)
                } catch let error as PSQLError {
                    if let stateString = error.serverInfo?[.sqlState] {
                        let code = PostgresError.Code(stringLiteral: stateString)
                        if code == .invalidCursorState || code == .invalidCursorName {
                            debugLog("Cursor exhausted (sqlState=\(stateString)); stopping fetch loop")
                            break fetchLoop
                        }
                    }
                    throw normalizeError(error, contextSQL: fetchSQL)
                } catch {
                    throw normalizeError(error, contextSQL: fetchSQL)
                }

                guard let batchSequence = optionalSequence else {
                    break fetchLoop
                }

                var batchRows: [[String?]] = []
                batchRows.reserveCapacity(fetchSize)
                var encodedRows: [ResultBinaryRow] = []
                encodedRows.reserveCapacity(fetchSize)
                var rawPayloadRows: [ResultRowPayload] = []
                rawPayloadRows.reserveCapacity(fetchSize)
                var batchCount = 0
                var fetchDecodeDuration: TimeInterval = 0
                var nextFetchSize = fetchSize

                func cheapStringValue(for cell: PostgresCell) -> String? {
                    if cell.format == .text, var buffer = cell.bytes {
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

                for try await row in batchSequence {
                    try Task.checkCancellation()

                    if columns.isEmpty {
                        columns.reserveCapacity(row.count)
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

                    let conversionStart = CFAbsoluteTimeGetCurrent()
                    var payloadCells: [ResultCellPayload] = []
                    payloadCells.reserveCapacity(row.count)

                    let shouldFormatRow: Bool = {
                        if !formattingEnabled { return true }
                        switch formattingMode {
                        case .immediate:
                            return true
                        case .deferred:
                            return previewRows.count < streamingPreviewLimit
                        }
                    }()

                    var formattedRow: [String?] = []
                    if shouldFormatRow {
                        formattedRow.reserveCapacity(row.count)
                    }

                    for cell in row {
                        payloadCells.append(ResultCellPayload(cell: cell))
                        guard shouldFormatRow else { continue }

                        let displayValue: String?
                        if formattingEnabled {
                            switch formattingMode {
                            case .immediate:
                                displayValue = formatterContext.stringValue(for: cell)
                            case .deferred:
                                displayValue = formatterContext.stringValue(for: cell)
                            }
                        } else {
                            displayValue = cheapStringValue(for: cell) ?? formatterContext.stringValue(for: cell)
                        }
                        formattedRow.append(displayValue)
                    }

                    if shouldFormatRow {
                        let decodeDuration = CFAbsoluteTimeGetCurrent() - conversionStart
                        fetchDecodeDuration += decodeDuration
                    }

                    totalRowCount += 1
                    batchCount += 1
                    rawPayloadRows.append(ResultRowPayload(cells: payloadCells))

                    if shouldFormatRow {
                        batchRows.append(formattedRow)
                        let encodedRow = ResultBinaryRowCodec.encode(row: formattedRow)
                        encodedRows.append(encodedRow)
                        if previewRows.count < streamingPreviewLimit {
                            previewRows.append(formattedRow)
                        }
                    }

                    if !firstRowLogged {
                        firstRowLogged = true
                        let firstRowLatency = CFAbsoluteTimeGetCurrent() - operationStart
                        let message = String(
                            format: "[PostgresStream] first-row latency=%.3fs",
                            firstRowLatency
                        )
                        logger.debug(.init(stringLiteral: message))
                        print(message)
                    }

                    if totalRowCount % 2048 == 0 {
                        await Task.yield()
                    }
                }

                let fetchDuration = CFAbsoluteTimeGetCurrent() - fetchStart
                let networkWait = max(fetchDuration - fetchDecodeDuration, 0)
                let fetchMessage = String(
                    format: "[PostgresStream] fetch requested=%d rows=%d duration=%.3fs wait=%.3fs",
                    fetchSize,
                    batchCount,
                    fetchDuration,
                    networkWait
                )
                logger.debug(.init(stringLiteral: fetchMessage))
                print(fetchMessage)
#if DEBUG
                debugLog("Fetch completed rows=\(batchCount) totalRowCount=\(totalRowCount) decode=\(String(format: "%.3f", fetchDecodeDuration)) wait=\(String(format: "%.3f", networkWait))")
#endif

                os_log("FetchBatch end rows=%{public}d", log: postgresFetchLog, type: .info, batchCount)
                print("[Signpost] FetchBatch end rows=\(batchCount)")
                if #available(macOS 10.14, *) {
                    os_signpost(.end, log: postgresFetchLog, name: "FetchBatch", "%{public}d rows", batchCount)
                }

                if batchCount == 0 {
                    break fetchLoop
                }

                let rowRange = (totalRowCount - batchCount)..<totalRowCount
                let metrics = QueryStreamMetrics(
                    batchRowCount: batchCount,
                    loopElapsed: fetchDuration,
                    decodeDuration: fetchDecodeDuration,
                    totalElapsed: CFAbsoluteTimeGetCurrent() - operationStart,
                    cumulativeRowCount: totalRowCount,
                    fetchRequestRowCount: fetchSize,
                    fetchRowCount: batchCount,
                    fetchDuration: fetchDuration,
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
                        batchCount,
                        now - operationStart
                    )
                    logger.debug(.init(stringLiteral: message))
                    print(message)
#if DEBUG
                    debugLog("First batch handler rows=\(batchCount)")
#endif
                }

                await MainActor.run {
                    progressHandler(update)
                }

                if batchCount < fetchSize {
                    break fetchLoop
                }

                let rampedBaseline = rampedBaselineForTotal(totalRowCount)
                if dynamicBackgroundFetchSize < rampedBaseline {
                    dynamicBackgroundFetchSize = rampedBaseline
                }

                if totalRowCount >= streamingPreviewLimit {
                    nextFetchSize = min(dynamicBackgroundFetchSize, maxAutoFetchSize)
                } else {
                    nextFetchSize = previewFetchSize
                }

                if batchCount == fetchSize {
                    if dynamicBackgroundFetchSize < maxAutoFetchSize {
                        let increased = min(
                            max(dynamicBackgroundFetchSize + previewFetchSize, dynamicBackgroundFetchSize * 3 / 2),
                            maxAutoFetchSize
                        )
                        if increased > dynamicBackgroundFetchSize {
                            dynamicBackgroundFetchSize = increased
                        }
                    }
                }

                fetchSize = nextFetchSize

                await Task.yield()
            }

            if cursorActive {
                try await executeVoidStatement("CLOSE \(cursorName)")
                cursorActive = false
            }
            if transactionBegan {
                try await executeVoidStatement("COMMIT")
                transactionBegan = false
            }
        } catch {
            if cursorActive {
                try? await executeVoidStatement("CLOSE \(cursorName)")
            }
            if transactionBegan {
                try? await executeVoidStatement("ROLLBACK")
            }

            if let cancellation = error as? CancellationError {
                throw cancellation
            }
            throw normalizeError(error, contextSQL: sanitizedSQL)
        }

        let totalElapsed = CFAbsoluteTimeGetCurrent() - operationStart
        let completionMessage = String(
            format: "[PostgresStream] completed rows=%d elapsed=%.3fs",
            totalRowCount,
            totalElapsed
        )
        logger.debug(.init(stringLiteral: completionMessage))
        print(completionMessage)
#if DEBUG
        debugLog("Streaming complete totalRows=\(totalRowCount)")
#endif

        let resolvedColumns = columns.isEmpty
            ? [ColumnInfo(name: "result", dataType: "text")]
            : columns

        return QueryResultSet(
            columns: resolvedColumns,
            rows: previewRows,
            totalRowCount: totalRowCount
        )
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

        let storedRampMax = UserDefaults.standard.integer(forKey: ResultStreamingFetchRampMaxDefaultsKey)
        let resolvedRampMax = storedRampMax >= 256 ? storedRampMax : 524_288
        let rampCeiling = max(backgroundFetchBaseline, min(resolvedRampMax, 1_048_576))
        let maxAutoFetchSize = min(rampCeiling, 262_144)

        return try await self.client.withConnection { connection in
            var columns: [ColumnInfo] = []
            var previewRows: [[String?]] = []
            previewRows.reserveCapacity(streamingPreviewLimit)
            var totalRowCount = 0
            var firstBatchDelivered = false
            var firstRowLogged = false
            var commandTag: String?

            var batchRows: [[String?]] = []
            batchRows.reserveCapacity(previewFetchSize)
            var encodedRows: [ResultBinaryRow] = []
            encodedRows.reserveCapacity(previewFetchSize)
            var rawPayloadRows: [ResultRowPayload] = []
            rawPayloadRows.reserveCapacity(previewFetchSize)
            var batchCount = 0
            var batchDecodeDuration: TimeInterval = 0
            var flushRequestRowCount = previewFetchSize
            var batchStartTime = CFAbsoluteTimeGetCurrent()
            var dynamicBackgroundFlushSize = backgroundFetchBaseline

            func cheapStringValue(for cell: PostgresCell) -> String? {
                if cell.format == .text, var buffer = cell.bytes {
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

            func resetBatch() {
                batchRows.removeAll(keepingCapacity: true)
                encodedRows.removeAll(keepingCapacity: true)
                rawPayloadRows.removeAll(keepingCapacity: true)
                batchCount = 0
                batchDecodeDuration = 0
                batchStartTime = CFAbsoluteTimeGetCurrent()
            }

            func publishBatch(expectedRequestSize: Int, rampEligible: Bool) {
                guard batchCount > 0 else { return }
                let flushedCount = batchCount
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
                debugLog("Flush completed rows=\(flushedCount) totalRowCount=\(totalRowCount) decode=\(String(format: "%.3f", batchDecodeDuration)) wait=\(String(format: "%.3f", networkWait)) rampEligible=\(rampEligible)")
#endif

                Task {
                    await MainActor.run {
                        progressHandler(update)
                    }
                }

                resetBatch()

                if totalRowCount >= streamingPreviewLimit {
                    if dynamicBackgroundFlushSize < 16_384 {
                        let elevated = min(maxAutoFetchSize, max(16_384, backgroundFetchBaseline))
                        dynamicBackgroundFlushSize = elevated
                    }

                    if rampEligible,
                       flushedCount >= flushRequestRowCount,
                       dynamicBackgroundFlushSize < maxAutoFetchSize {
                        let doubled = dynamicBackgroundFlushSize * 2
                        let additive = dynamicBackgroundFlushSize + backgroundFetchBaseline
                        let candidate = max(doubled, max(additive, dynamicBackgroundFlushSize + previewFetchSize))
                        let nextSize = min(maxAutoFetchSize, candidate)
                        if nextSize > dynamicBackgroundFlushSize {
                            dynamicBackgroundFlushSize = nextSize
                        }
                    }

                    flushRequestRowCount = dynamicBackgroundFlushSize
                } else {
                    flushRequestRowCount = previewFetchSize
                }
            }

            let query = PostgresQuery(unsafeSQL: sanitizedSQL)

            do {
                let metadata = try await connection.query(query, logger: logger) { row in
                    if Task.isCancelled {
                        throw CancellationError()
                    }

                    if columns.isEmpty {
                        columns.reserveCapacity(row.count)
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

                    let conversionStart = CFAbsoluteTimeGetCurrent()
                    var payloadCells: [ResultCellPayload] = []
                    payloadCells.reserveCapacity(row.count)

                    let shouldFormatRow: Bool = {
                        if !formattingEnabled { return true }
                        switch formattingMode {
                        case .immediate:
                            return true
                        case .deferred:
                            return previewRows.count < streamingPreviewLimit
                        }
                    }()

                    var formattedRow: [String?] = []
                    if shouldFormatRow {
                        formattedRow.reserveCapacity(row.count)
                    }

                    for cell in row {
                        payloadCells.append(ResultCellPayload(cell: cell))
                        guard shouldFormatRow else { continue }

                        let displayValue: String?
                        if formattingEnabled {
                            switch formattingMode {
                            case .immediate:
                                displayValue = formatterContext.stringValue(for: cell)
                            case .deferred:
                                displayValue = formatterContext.stringValue(for: cell)
                            }
                        } else {
                            displayValue = cheapStringValue(for: cell) ?? formatterContext.stringValue(for: cell)
                        }
                        formattedRow.append(displayValue)
                    }

                    if shouldFormatRow {
                        let decodeDuration = CFAbsoluteTimeGetCurrent() - conversionStart
                        batchDecodeDuration += decodeDuration
                    }

                    totalRowCount += 1
                    batchCount += 1

                    let rowPayload = ResultRowPayload(cells: payloadCells)
                    rawPayloadRows.append(rowPayload)

                    if shouldFormatRow {
                        batchRows.append(formattedRow)
                        encodedRows.append(ResultBinaryRowCodec.encode(row: formattedRow))
                        if previewRows.count < streamingPreviewLimit {
                            previewRows.append(formattedRow)
                        }
                    } else {
                        let rawCells = payloadCells.map { $0.bytes }
                        encodedRows.append(ResultBinaryRowCodec.encodeRaw(cells: rawCells))
                    }

                    if !firstRowLogged {
                        firstRowLogged = true
                        let firstRowLatency = CFAbsoluteTimeGetCurrent() - operationStart
                        let message = String(
                            format: "[PostgresStream] first-row latency=%.3fs",
                            firstRowLatency
                        )
                        logger.debug(.init(stringLiteral: message))
                        print(message)
                    }

                    if totalRowCount < streamingPreviewLimit {
                        return
                    }

                    if totalRowCount == streamingPreviewLimit {
                        publishBatch(expectedRequestSize: batchCount, rampEligible: false)
                        return
                    }

                    let now = CFAbsoluteTimeGetCurrent()
                    let elapsedSinceBatchStart = now - batchStartTime
                    let dispatchThresholdReached = batchCount >= flushRequestRowCount
                    let rampEligible = dispatchThresholdReached

                    let timedFlushInterval: TimeInterval
                    let slowFlushInterval: TimeInterval
                    let timedThresholdRows: Int
                    let slowRowsThreshold: Int

                    if totalRowCount < streamingPreviewLimit {
                        timedFlushInterval = 0.12
                        slowFlushInterval = 0.35
                        timedThresholdRows = min(flushRequestRowCount, 256)
                        slowRowsThreshold = min(flushRequestRowCount, 64)
                    } else {
                        if flushRequestRowCount >= 131_072 {
                            timedFlushInterval = 1.4
                        } else if flushRequestRowCount >= 65_536 {
                            timedFlushInterval = 1.1
                        } else if flushRequestRowCount >= 16_384 {
                            timedFlushInterval = 0.85
                        } else {
                            timedFlushInterval = 0.65
                        }
                        slowFlushInterval = max(timedFlushInterval * 2.2, 2.2)

                        let thresholdA = max(
                            flushRequestRowCount - max(flushRequestRowCount / 8, 2_048),
                            0
                        )
                        let thresholdB = flushRequestRowCount * 3 / 4
                        timedThresholdRows = min(
                            flushRequestRowCount,
                            max(8_192, max(thresholdA, thresholdB))
                        )

                        slowRowsThreshold = max(min(flushRequestRowCount / 4, 2_048), 256)
                    }

                    let timedFlushEligible = batchCount >= min(timedThresholdRows, flushRequestRowCount)
                        && elapsedSinceBatchStart >= timedFlushInterval
                    let slowFlushEligible = batchCount >= slowRowsThreshold
                        && elapsedSinceBatchStart >= slowFlushInterval

#if DEBUG
                    if dispatchThresholdReached || timedFlushEligible || slowFlushEligible {
                        debugLog("Flush trigger dispatch=\(dispatchThresholdReached) timed=\(timedFlushEligible) slow=\(slowFlushEligible) count=\(batchCount) target=\(flushRequestRowCount) elapsed=\(String(format: "%.3f", elapsedSinceBatchStart))")
                    }
#endif

                    if dispatchThresholdReached || timedFlushEligible || slowFlushEligible {
                        let expectedSize = rampEligible ? flushRequestRowCount : batchCount
                        publishBatch(expectedRequestSize: expectedSize, rampEligible: rampEligible)
                    }
                }.get()
                commandTag = metadata.command
            } catch {
                throw normalizeError(error, contextSQL: sanitizedSQL)
            }

            if batchCount > 0 {
                let rampEligible = totalRowCount > streamingPreviewLimit
                let expectedSize = rampEligible ? flushRequestRowCount : batchCount
                publishBatch(expectedRequestSize: expectedSize, rampEligible: rampEligible)
            }

            let totalElapsed = CFAbsoluteTimeGetCurrent() - operationStart
            let completionMessage = String(
                format: "[PostgresStream] completed rows=%d elapsed=%.3fs",
                totalRowCount,
                totalElapsed
            )
            logger.debug(.init(stringLiteral: completionMessage))
            print(completionMessage)
#if DEBUG
            debugLog("Streaming complete totalRows=\(totalRowCount)")
#endif

            let resolvedColumns = columns.isEmpty
                ? [ColumnInfo(name: "result", dataType: "text")]
                : columns

            return QueryResultSet(
                columns: resolvedColumns,
                rows: previewRows,
                totalRowCount: totalRowCount,
                commandTag: commandTag
            )
        }
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
        let query = PostgresQuery(unsafeSQL: sql)
        let result = try await client.query(query, logger: logger)

        var count = 0
        for try await _ in result {
            count += 1
        }
        return count
    }

    func listDatabases() async throws -> [String] {
        let sql = """
        SELECT datname
        FROM pg_database
        WHERE datallowconn = true
          AND datistemplate = false
        ORDER BY datname;
        """
        let result = try await performQuery(sql)
        var names: [String] = []
        for try await name in result.decode(String.self) {
            names.append(name)
        }
        return names
    }

    func listSchemas() async throws -> [String] {
        let sql = """
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name NOT IN ('pg_catalog', 'pg_toast', 'information_schema')
          AND schema_name NOT LIKE 'pg_temp_%'
          AND schema_name NOT LIKE 'pg_toast_temp_%'
        ORDER BY schema_name;
        """
        let result = try await performQuery(sql)
        var schemas: [String] = []
        for try await schema in result.decode(String.self) {
            schemas.append(schema)
        }
        return schemas
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName = schema ?? "public"
        return try await loadSchemaInfo(schemaName, progress: nil).objects
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName ?? "public"
        let columnMap = try await fetchColumnsByObject(schemaName: schema)
        return columnMap[tableName] ?? []
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        @Sendable func fetchColumns() async throws -> [TableStructureDetails.Column] {
            var columns: [TableStructureDetails.Column] = []

            let columnsSQL = """
        SELECT
            column_name,
            data_type,
            is_nullable,
            column_default,
            generation_expression,
            ordinal_position
        FROM information_schema.columns
        WHERE table_schema = $1 AND table_name = $2
        ORDER BY ordinal_position;
        """

            let columnResult = try await performQuery(columnsSQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
            for try await (name, dataType, nullable, defaultValue, generated, _) in columnResult.decode((String, String, String, String?, String?, Int).self) {
                let column = TableStructureDetails.Column(
                    name: name,
                    dataType: dataType,
                    isNullable: nullable.uppercased() == "YES",
                    defaultValue: defaultValue,
                    generatedExpression: generated
                )
                columns.append(column)
            }
            return columns
        }

        @Sendable func fetchPrimaryKey() async throws -> TableStructureDetails.PrimaryKey? {
            var primaryKeyName: String?
            var primaryKeyColumns: [String] = []

            let primaryKeySQL = """
        SELECT tc.constraint_name, kcu.column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = $1
          AND tc.table_name = $2
        ORDER BY kcu.ordinal_position;
        """

            let pkResult = try await performQuery(primaryKeySQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
            for try await (name, column) in pkResult.decode((String, String).self) {
                primaryKeyName = name
                primaryKeyColumns.append(column)
            }

            if let pkName = primaryKeyName {
                return TableStructureDetails.PrimaryKey(name: pkName, columns: primaryKeyColumns)
            }
            return nil
        }

        @Sendable func fetchIndexes() async throws -> [TableStructureDetails.Index] {
            struct IndexAccumulator {
                var isUnique: Bool
                var columns: [TableStructureDetails.Index.Column]
                var filterCondition: String?
            }

            var indexes: [String: IndexAccumulator] = [:]
            let indexSQL = """
        SELECT
            idx.relname AS index_name,
            ix.indisunique,
            ord.position,
            att.attname,
            ((ix.indoption[ord.position] & 1) = 1) AS is_descending,
            pg_get_expr(ix.indpred, tab.oid) AS predicate
        FROM pg_class tab
        JOIN pg_index ix ON tab.oid = ix.indrelid
        JOIN pg_class idx ON idx.oid = ix.indexrelid
        JOIN pg_namespace ns ON ns.oid = tab.relnamespace
        CROSS JOIN LATERAL generate_subscripts(ix.indkey, 1) AS ord(position)
        LEFT JOIN pg_attribute att ON att.attrelid = tab.oid AND att.attnum = ix.indkey[ord.position]
        WHERE ns.nspname = $1
          AND tab.relname = $2
          AND ix.indisprimary = false
        ORDER BY idx.relname, ord.position;
        """

            let indexResult = try await performQuery(indexSQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
            for try await (indexName, isUnique, position, column, isDescendingRaw, predicate) in indexResult.decode((String, Bool, Int, String?, Bool?, String?).self) {
                var entry = indexes[indexName] ?? IndexAccumulator(isUnique: isUnique, columns: [], filterCondition: predicate)
                entry.filterCondition = predicate
                if let column {
                    let isDescending = isDescendingRaw ?? false
                    let sortOrder: TableStructureDetails.Index.Column.SortOrder = isDescending ? .descending : .ascending
                    entry.columns.append(
                        TableStructureDetails.Index.Column(
                            name: column,
                            position: position,
                            sortOrder: sortOrder
                        )
                    )
                }
                indexes[indexName] = entry
            }

            return indexes.map { name, value in
                let sortedColumns = value.columns.sorted { $0.position < $1.position }
                return TableStructureDetails.Index(
                    name: name,
                    columns: sortedColumns,
                    isUnique: value.isUnique,
                    filterCondition: value.filterCondition?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        @Sendable func fetchUniqueConstraints() async throws -> [TableStructureDetails.UniqueConstraint] {
            var uniqueConstraints: [String: [String]] = [:]
            let uniqueSQL = """
        SELECT tc.constraint_name, kcu.column_name, kcu.ordinal_position
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'UNIQUE'
          AND tc.table_schema = $1
          AND tc.table_name = $2
        ORDER BY tc.constraint_name, kcu.ordinal_position;
        """

            let uniqueResult = try await performQuery(uniqueSQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
            for try await (name, column, _) in uniqueResult.decode((String, String, Int).self) {
                uniqueConstraints[name, default: []].append(column)
            }

            return uniqueConstraints.map { name, columns in
                TableStructureDetails.UniqueConstraint(name: name, columns: columns)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        @Sendable func fetchForeignKeys() async throws -> [TableStructureDetails.ForeignKey] {
            struct ForeignKeyRow {
                let name: String
                let column: String
                let referencedSchema: String
                let referencedTable: String
                let referencedColumn: String
                let onUpdate: String?
                let onDelete: String?
                let position: Int
            }

            var foreignKeyRows: [ForeignKeyRow] = []
            let foreignKeySQL = """
        SELECT
            tc.constraint_name,
            kcu.column_name,
            ccu.table_schema,
            ccu.table_name,
            ccu.column_name,
            rc.update_rule,
            rc.delete_rule,
            kcu.ordinal_position
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.referential_constraints AS rc
          ON rc.constraint_name = tc.constraint_name
          AND rc.constraint_schema = tc.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.constraint_schema = tc.constraint_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = $1
          AND tc.table_name = $2
        ORDER BY tc.constraint_name, kcu.ordinal_position;
        """

            let foreignResult = try await performQuery(foreignKeySQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
            for try await (name, column, refSchema, refTable, refColumn, onUpdate, onDelete, position) in foreignResult.decode((String, String, String, String, String, String?, String?, Int).self) {
                foreignKeyRows.append(
                    ForeignKeyRow(
                        name: name,
                        column: column,
                        referencedSchema: refSchema,
                        referencedTable: refTable,
                        referencedColumn: refColumn,
                        onUpdate: onUpdate,
                        onDelete: onDelete,
                        position: position
                    )
                )
            }

            let groupedFK = Dictionary(grouping: foreignKeyRows, by: { $0.name })
            return groupedFK.map { name, rows in
                let sortedRows = rows.sorted { $0.position < $1.position }
                return TableStructureDetails.ForeignKey(
                    name: name,
                    columns: sortedRows.map { $0.column },
                    referencedSchema: sortedRows.first?.referencedSchema ?? schema,
                    referencedTable: sortedRows.first?.referencedTable ?? "",
                    referencedColumns: sortedRows.map { $0.referencedColumn },
                    onUpdate: sortedRows.first?.onUpdate,
                    onDelete: sortedRows.first?.onDelete
                )
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        @Sendable func fetchDependencies() async throws -> [TableStructureDetails.Dependency] {
            struct DependencyRow {
                let name: String
                let sourceTable: String
                let referencingColumn: String
                let referencedColumn: String
                let onUpdate: String?
                let onDelete: String?
                let position: Int
            }

            var dependencyRows: [DependencyRow] = []
            let dependencySQL = """
        SELECT
            tc.constraint_name,
            kcu.table_schema,
            kcu.table_name,
            kcu.column_name,
            ccu.column_name,
            rc.update_rule,
            rc.delete_rule,
            kcu.ordinal_position
        FROM information_schema.referential_constraints AS rc
        JOIN information_schema.table_constraints AS tc
          ON tc.constraint_name = rc.constraint_name
          AND tc.constraint_schema = rc.constraint_schema
        JOIN information_schema.key_column_usage AS kcu
          ON kcu.constraint_name = tc.constraint_name
          AND kcu.constraint_schema = tc.constraint_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.constraint_schema = tc.constraint_schema
        WHERE ccu.table_schema = $1
          AND ccu.table_name = $2
        ORDER BY tc.constraint_name, kcu.ordinal_position;
        """

            let dependencyResult = try await performQuery(dependencySQL, binds: [PostgresData(string: schema), PostgresData(string: table)])
            for try await (name, sourceSchema, sourceTable, sourceColumn, targetColumn, onUpdate, onDelete, position) in dependencyResult.decode((String, String, String, String, String, String?, String?, Int).self) {
                let fullSourceTable: String
                if sourceSchema == schema {
                    fullSourceTable = sourceTable
                } else {
                    fullSourceTable = "\(sourceSchema).\(sourceTable)"
                }

                dependencyRows.append(
                    DependencyRow(
                        name: name,
                        sourceTable: fullSourceTable,
                        referencingColumn: sourceColumn,
                        referencedColumn: targetColumn,
                        onUpdate: onUpdate,
                        onDelete: onDelete,
                        position: position
                    )
                )
            }

            let groupedDependencies = Dictionary(grouping: dependencyRows, by: { $0.name })
            return groupedDependencies.map { name, rows in
                let sortedRows = rows.sorted { $0.position < $1.position }
                return TableStructureDetails.Dependency(
                    name: name,
                    baseColumns: sortedRows.map { $0.referencingColumn },
                    referencedTable: sortedRows.first?.sourceTable ?? "",
                    referencedColumns: sortedRows.map { $0.referencedColumn },
                    onUpdate: sortedRows.first?.onUpdate,
                    onDelete: sortedRows.first?.onDelete
                )
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        async let columnsTask = fetchColumns()
        async let primaryKeyTask = fetchPrimaryKey()
        async let indexesTask = fetchIndexes()
        async let uniqueConstraintsTask = fetchUniqueConstraints()
        async let foreignKeysTask = fetchForeignKeys()
        async let dependenciesTask = fetchDependencies()

        let (columns, primaryKey, indexes, uniqueConstraints, foreignKeys, dependencies) = try await (
            columnsTask,
            primaryKeyTask,
            indexesTask,
            uniqueConstraintsTask,
            foreignKeysTask,
            dependenciesTask
        )

        return TableStructureDetails(
            columns: columns,
            primaryKey: primaryKey,
            indexes: indexes,
            uniqueConstraints: uniqueConstraints,
            foreignKeys: foreignKeys,
            dependencies: dependencies
        )
    }

    private func fetchColumnsByObject(schemaName: String) async throws -> [String: [ColumnInfo]] {
        struct ColumnRecord {
            let name: String
            let dataType: String
            let isNullable: Bool
            let maxLength: Int?
            let ordinal: Int
        }

        var columnsByTable: [String: [ColumnRecord]] = [:]

        let columnsSQL = """
        SELECT table_name, column_name, data_type, is_nullable, character_maximum_length, ordinal_position
        FROM information_schema.columns
        WHERE table_schema = $1
        ORDER BY table_name, ordinal_position;
        """
        let columnResult = try await performQuery(columnsSQL, binds: [PostgresData(string: schemaName)])
        for try await (table, column, dataType, nullable, maxLength, ordinal) in columnResult.decode((String, String, String, String, Int?, Int).self) {
            var list = columnsByTable[table, default: []]
            list.append(
                ColumnRecord(
                    name: column,
                    dataType: dataType,
                    isNullable: nullable.uppercased() == "YES",
                    maxLength: maxLength,
                    ordinal: ordinal
                )
            )
            columnsByTable[table] = list
        }

        let pkSQL = """
        SELECT tc.table_name, kcu.column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = $1;
        """
        var primaryKeysByTable: [String: Set<String>] = [:]
        let pkResult = try await performQuery(pkSQL, binds: [PostgresData(string: schemaName)])
        for try await (table, column) in pkResult.decode((String, String).self) {
            var columns = primaryKeysByTable[table, default: []]
            columns.insert(column)
            primaryKeysByTable[table] = columns
        }

        let foreignKeysSQL = """
        SELECT
            cls.relname AS table_name,
            att.attname AS column_name,
            nsp_ref.nspname AS referenced_schema,
            cls_ref.relname AS referenced_table,
            att_ref.attname AS referenced_column,
            con.conname AS constraint_name
        FROM pg_constraint con
        JOIN pg_class cls ON cls.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = cls.relnamespace
        JOIN pg_class cls_ref ON cls_ref.oid = con.confrelid
        JOIN pg_namespace nsp_ref ON nsp_ref.oid = cls_ref.relnamespace
        JOIN LATERAL generate_subscripts(con.conkey, 1) AS idx(pos) ON TRUE
        JOIN pg_attribute att ON att.attrelid = con.conrelid AND att.attnum = con.conkey[idx.pos]
        JOIN pg_attribute att_ref ON att_ref.attrelid = con.confrelid AND att_ref.attnum = con.confkey[idx.pos]
        WHERE con.contype = 'f'
          AND nsp.nspname = $1
        ORDER BY cls.relname, idx.pos;
        """

        var foreignKeysByTable: [String: [String: ColumnInfo.ForeignKeyReference]] = [:]
        let foreignKeysResult = try await performQuery(foreignKeysSQL, binds: [PostgresData(string: schemaName)])
        for try await (table, column, referencedSchema, referencedTable, referencedColumn, constraintName) in foreignKeysResult.decode((String, String, String, String, String, String).self) {
            var tableMap = foreignKeysByTable[table, default: [:]]
            tableMap[column] = ColumnInfo.ForeignKeyReference(
                constraintName: constraintName,
                referencedSchema: referencedSchema,
                referencedTable: referencedTable,
                referencedColumn: referencedColumn
            )
            foreignKeysByTable[table] = tableMap
        }

        // Materialized view columns may not appear in information_schema in some versions
        let matViewColumnSQL = """
        SELECT c.relname, a.attname, pg_catalog.format_type(a.atttypid, a.atttypmod), NOT a.attnotnull, NULL::integer, a.attnum
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = $1
          AND c.relkind = 'm'
          AND a.attnum > 0
          AND NOT a.attisdropped
        ORDER BY c.relname, a.attnum;
        """
        let matResult = try await performQuery(matViewColumnSQL, binds: [PostgresData(string: schemaName)])
        for try await (table, column, dataType, nullable, _, ordinal) in matResult.decode((String, String, String, Bool, Int?, Int).self) {
            var list = columnsByTable[table, default: []]
            list.append(
                ColumnRecord(
                    name: column,
                    dataType: dataType,
                    isNullable: nullable,
                    maxLength: nil,
                    ordinal: ordinal
                )
            )
            columnsByTable[table] = list
        }

        var result: [String: [ColumnInfo]] = [:]
        for (table, records) in columnsByTable {
            let sorted = records.sorted { $0.ordinal < $1.ordinal }
            let primaryKeys = primaryKeysByTable[table] ?? []
            let foreignKeys = foreignKeysByTable[table] ?? [:]
            let columns = sorted.map { record in
                ColumnInfo(
                    name: record.name,
                    dataType: record.dataType,
                    isPrimaryKey: primaryKeys.contains(record.name),
                    isNullable: record.isNullable,
                    maxLength: record.maxLength,
                    foreignKey: foreignKeys[record.name]
                )
            }
            result[table] = columns
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
            let sql = """
            SELECT pg_get_viewdef(format('%I.%I', $1, $2)::regclass, true);
            """
            if let definition = try await firstString(sql, binds: [PostgresData(string: schemaName), PostgresData(string: objectName)]) {
                return definition
            }
            return "-- View definition unavailable"

        case .function, .procedure:
            let sql = """
            SELECT pg_catalog.pg_get_functiondef(p.oid)
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = $1 AND p.proname = $2
            ORDER BY p.oid
            LIMIT 1;
            """
            if let definition = try await firstString(sql, binds: [PostgresData(string: schemaName), PostgresData(string: objectName)]) {
                return definition
            }
            return "-- Function definition unavailable"

        case .trigger:
            let sql = """
            SELECT pg_catalog.pg_get_triggerdef(t.oid, true)
            FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = $1 AND t.tgname = $2
            ORDER BY t.oid
            LIMIT 1;
            """
            if let definition = try await firstString(sql, binds: [PostgresData(string: schemaName), PostgresData(string: objectName)]) {
                return definition
            }
            return "-- Trigger definition unavailable"
        }
    }

    // MARK: - Helpers

    private func performQuery(_ sql: String, binds: [PostgresData] = []) async throws -> PostgresRowSequence {
        let query = makeQuery(sql, binds: binds)
        return try await client.query(query, logger: logger)
    }

    private func makeQuery(_ sql: String, binds: [PostgresData]) -> PostgresQuery {
        guard !binds.isEmpty else {
            return PostgresQuery(unsafeSQL: sql)
        }

        var bindings = PostgresBindings()
        for bind in binds {
            bindings.append(bind)
        }
        return PostgresQuery(unsafeSQL: sql, binds: bindings)
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

struct CellFormatterContext {
    private static let postgresEpoch: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2000
        components.month = 1
        components.day = 1
        return components.date!
    }()

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    func stringValue(for cell: PostgresCell) -> String? {
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

    private func integerString<Integer>(from cell: PostgresCell, as type: Integer.Type) -> String?
    where Integer: FixedWidthInteger & PostgresDecodable {
        guard let value = try? cell.decode(type, context: .default) else { return nil }
        return String(value)
    }

    private func hexString(from buffer: inout ByteBuffer) -> String {
        let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func formatTimestamp(microseconds: Int64) -> String {
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

    private func formatTimestampWithTimeZone(microseconds: Int64) -> String {
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

    private func formatDate(days: Int) -> String {
        if let date = Self.utcCalendar.date(byAdding: .day, value: days, to: Self.postgresEpoch) {
            let components = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
            if let year = components.year, let month = components.month, let day = components.day {
                return String(format: "%04d-%02d-%02d", year, month, day)
            }
        }
        return ""
    }

    private func formatTime(microseconds: Int64) -> String {
        let (seconds, microsRemainder) = Self.splitMicroseconds(microseconds)
        let normalizedSeconds = ((seconds % 86_400) + 86_400) % 86_400
        let hour = normalizedSeconds / 3_600
        let minute = (normalizedSeconds % 3_600) / 60
        let second = normalizedSeconds % 60
        let fractional = formatFractionalMicroseconds(microsRemainder)
        return String(format: "%02d:%02d:%02d%@", hour, minute, second, fractional)
    }

    private func formatTimeWithTimeZone(microseconds: Int64, offsetMinutesWest: Int) -> String {
        let timeString = formatTime(microseconds: microseconds)
        let minutesEast = -offsetMinutesWest
        let sign = minutesEast >= 0 ? "+" : "-"
        let absoluteMinutes = abs(minutesEast)
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        return String(format: "%@%@%02d:%02d", timeString, sign, hours, minutes)
    }

    private static func splitMicroseconds(_ value: Int64) -> (seconds: Int64, remainder: Int64) {
        var seconds = value / 1_000_000
        var remainder = value % 1_000_000
        if remainder < 0 {
            remainder += 1_000_000
            seconds -= 1
        }
        return (seconds, remainder)
    }

    private func formatFractionalMicroseconds(_ value: Int64) -> String {
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
        let columnsByObject = try await fetchColumnsByObject(schemaName: schemaName)

        var objects: [SchemaObjectInfo] = []

        let tableSQL = """
        SELECT table_name, table_type
        FROM information_schema.tables
        WHERE table_schema = $1
          AND table_type IN ('BASE TABLE', 'VIEW')
        ORDER BY table_type, table_name;
        """
        let tableResult = try await performQuery(tableSQL, binds: [PostgresData(string: schemaName)])
        var tableEntries: [(String, SchemaObjectInfo.ObjectType)] = []
        for try await (name, rawType) in tableResult.decode((String, String).self) {
            let type = SchemaObjectInfo.ObjectType(rawValue: rawType) ?? .table
            tableEntries.append((name, type))
        }

        let materializedViewSQL = """
        SELECT matviewname
        FROM pg_matviews
        WHERE schemaname = $1
        ORDER BY matviewname;
        """
        let matResult = try await performQuery(materializedViewSQL, binds: [PostgresData(string: schemaName)])
        var materializedNames: [String] = []
        for try await name in matResult.decode(String.self) {
            materializedNames.append(name)
        }

        let functionSQL = """
        SELECT routine_name
        FROM information_schema.routines
        WHERE specific_schema = $1
          AND routine_type = 'FUNCTION'
        ORDER BY routine_name;
        """
        let functionResult = try await performQuery(functionSQL, binds: [PostgresData(string: schemaName)])
        var functionNames: [String] = []
        for try await name in functionResult.decode(String.self) {
            functionNames.append(name)
        }

        let triggerSQL = """
        SELECT trigger_name, action_timing, event_manipulation, event_object_table
        FROM information_schema.triggers
        WHERE trigger_schema = $1
        ORDER BY trigger_name;
        """
        let triggerResult = try await performQuery(triggerSQL, binds: [PostgresData(string: schemaName)])
        var triggerRows: [(String, String, String, String)] = []
        for try await tuple in triggerResult.decode((String, String, String, String).self) {
            triggerRows.append(tuple)
        }

        let totalObjectsCount = max(
            tableEntries.count + materializedNames.count + functionNames.count + triggerRows.count,
            1
        )
        var processedObjects = 0

        if let progress {
            await progress(.table, processedObjects, totalObjectsCount)
        }
        for (name, type) in tableEntries {
            processedObjects += 1
            if let progress {
                await progress(type, processedObjects, totalObjectsCount)
            }
            let columns = columnsByObject[name] ?? []
            objects.append(
                SchemaObjectInfo(
                    name: name,
                    schema: schemaName,
                    type: type,
                    columns: columns
                )
            )
        }

        if !materializedNames.isEmpty {
            if let progress {
                await progress(.materializedView, processedObjects, totalObjectsCount)
            }
            for name in materializedNames {
                processedObjects += 1
                if let progress {
                    await progress(.materializedView, processedObjects, totalObjectsCount)
                }
                let columns = columnsByObject[name] ?? []
                objects.append(
                    SchemaObjectInfo(
                        name: name,
                        schema: schemaName,
                        type: .materializedView,
                        columns: columns
                    )
                )
            }
        }

        if !functionNames.isEmpty {
            if let progress {
                await progress(.function, processedObjects, totalObjectsCount)
            }
            for name in functionNames {
                processedObjects += 1
                if let progress {
                    await progress(.function, processedObjects, totalObjectsCount)
                }
                objects.append(
                    SchemaObjectInfo(
                        name: name,
                        schema: schemaName,
                        type: .function
                    )
                )
            }
        }

        if !triggerRows.isEmpty {
            if let progress {
                await progress(.trigger, processedObjects, totalObjectsCount)
            }
            for row in triggerRows {
                let (name, timing, action, table) = row
                let actionDisplay = "\(timing.uppercased()) \(action.uppercased())".trimmingCharacters(in: .whitespaces)
                let tableName = "\(schemaName).\(table)"
                processedObjects += 1
                if let progress {
                    await progress(.trigger, processedObjects, totalObjectsCount)
                }
                objects.append(
                    SchemaObjectInfo(
                        name: name,
                        schema: schemaName,
                        type: .trigger,
                        columns: [],
                        triggerAction: actionDisplay,
                        triggerTable: tableName
                    )
                )
            }
        }

        return SchemaInfo(name: schemaName, objects: objects)
    }
}

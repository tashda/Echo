import Foundation
import SQLServerKit
import Logging

extension SQLServerSessionAdapter {
    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        let rows: [SQLServerRow] = try await client.query(sql)
        return convertSQLServerRowsToEcho(rows)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        guard let progressHandler else {
            return try await simpleQuery(sql)
        }
        return try await streamQueryWithProgress(sql, progressHandler: progressHandler)
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        return try await simpleQuery(sql, progressHandler: progressHandler)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let rows = try await client.queryPaged(sql, limit: limit, offset: offset)
        return convertSQLServerRowsToEcho(rows)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let result = try await client.execute(sql)
        return Int(result.rowCount ?? 0)
    }

    func renameTable(schema: String?, oldName: String, newName: String) async throws {
        try await client.admin.renameTable(
            name: oldName,
            newName: newName,
            schema: schema ?? "dbo",
            database: database
        )
    }

    func dropTable(schema: String?, name: String, ifExists: Bool) async throws {
        try await client.admin.dropTable(
            name: name,
            schema: schema ?? "dbo",
            database: database
        )
    }

    func truncateTable(schema: String?, name: String) async throws {
        try await client.admin.truncateTable(
            name: name,
            schema: schema ?? "dbo",
            database: database
        )
    }

    // MARK: - Streaming

    private func streamQueryWithProgress(
        _ sql: String,
        progressHandler: @escaping QueryProgressHandler
    ) async throws -> QueryResultSet {
        let operationStart = CFAbsoluteTimeGetCurrent()
        let initialPreviewBatch = 200
        let maxFlushLatency: TimeInterval = 0.015
        let batchEnqueueSize = 512

        let bridgedHandler: QueryProgressHandler = { update in
            DispatchQueue.main.async {
                progressHandler(update)
            }
        }

        let (_, stream) = try await client.streamQuery(sql)

        // Track which result set we're on (0 = primary, 1+ = additional)
        var resultSetIndex = -1

        // Primary result set state (streamed progressively)
        var primaryColumns: [ColumnInfo] = []
        var primaryPreviewRows: [[String?]] = []
        primaryPreviewRows.reserveCapacity(initialPreviewBatch)
        var primaryRowCount = 0
        var worker: ResultStreamBatchWorker?
        var pendingPayloads: [ResultStreamBatchWorker.Payload] = []
        pendingPayloads.reserveCapacity(batchEnqueueSize)
        var firstRowLogged = false

        // Additional result sets (accumulated, not streamed)
        var additionalResults: [QueryResultSet] = []
        var currentAdditionalColumns: [ColumnInfo] = []
        var currentAdditionalRows: [[String?]] = []

        var errorMessage: SQLServerStreamMessage?

        for try await event in stream {
            if Task.isCancelled {
                throw CancellationError()
            }

            switch event {
            case .metadata(let columnDescriptions):
                // Finalize previous additional result set if in progress
                if resultSetIndex > 0 && !currentAdditionalColumns.isEmpty {
                    additionalResults.append(QueryResultSet(
                        columns: currentAdditionalColumns,
                        rows: currentAdditionalRows,
                        totalRowCount: currentAdditionalRows.count
                    ))
                }

                resultSetIndex += 1
                let columns = columnDescriptions.map { col in
                    ColumnInfo(
                        name: col.name,
                        dataType: col.type.name,
                        isPrimaryKey: false,
                        isNullable: (col.flags & 0x01) != 0,
                        maxLength: col.length > 0 ? col.length : nil
                    )
                }

                if resultSetIndex == 0 {
                    primaryColumns = columns
                    worker = ResultStreamBatchWorker(
                        label: "dk.tippr.echo.mssql.streamWorker",
                        columns: columns,
                        streamingPreviewLimit: initialPreviewBatch,
                        maxFlushLatency: maxFlushLatency,
                        operationStart: operationStart,
                        progressHandler: bridgedHandler
                    )
                } else {
                    currentAdditionalColumns = columns
                    currentAdditionalRows = []
                }

            case .row(let row):
                let stringValues = row.values.map { value -> String? in
                    value.isNull ? nil : value.description
                }

                if resultSetIndex == 0 {
                    primaryRowCount += 1

                    if primaryRowCount <= initialPreviewBatch {
                        primaryPreviewRows.append(stringValues)
                        pendingPayloads.append(ResultStreamBatchWorker.Payload(
                            previewValues: stringValues,
                            storage: .stringValues(stringValues),
                            totalRowCount: primaryRowCount,
                            decodeDuration: 0
                        ))
                    } else {
                        pendingPayloads.append(ResultStreamBatchWorker.Payload(
                            previewValues: nil,
                            storage: .stringValues(stringValues),
                            totalRowCount: primaryRowCount,
                            decodeDuration: 0
                        ))
                    }

                    if pendingPayloads.count >= batchEnqueueSize {
                        worker?.enqueueBatch(pendingPayloads)
                        pendingPayloads.removeAll(keepingCapacity: true)
                    }

                    if !firstRowLogged {
                        firstRowLogged = true
                        let latency = CFAbsoluteTimeGetCurrent() - operationStart
                        logger.debug("[MSSQLStream] first-row latency=\(String(format: "%.3f", latency))s")
                    }
                } else {
                    currentAdditionalRows.append(stringValues)
                }

            case .message(let msg):
                if msg.kind == .error {
                    errorMessage = msg
                }

            case .done:
                break
            }
        }

        // Finalize last additional result set if any
        if resultSetIndex > 0 && !currentAdditionalColumns.isEmpty {
            additionalResults.append(QueryResultSet(
                columns: currentAdditionalColumns,
                rows: currentAdditionalRows,
                totalRowCount: currentAdditionalRows.count
            ))
        }

        if let err = errorMessage {
            throw DatabaseError.queryError(err.message)
        }

        if !pendingPayloads.isEmpty {
            worker?.enqueueBatch(pendingPayloads)
        }

        if let worker {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                worker.finish(totalRowCount: primaryRowCount) {
                    DispatchQueue.main.async {
                        continuation.resume()
                    }
                }
            }
        }

        let totalElapsed = CFAbsoluteTimeGetCurrent() - operationStart
        logger.debug("[MSSQLStream] completed sets=\(resultSetIndex + 1) primaryRows=\(primaryRowCount) additionalSets=\(additionalResults.count) elapsed=\(String(format: "%.3f", totalElapsed))s")

        let resolvedColumns = primaryColumns.isEmpty
            ? [ColumnInfo(name: "result", dataType: "text")]
            : primaryColumns

        return QueryResultSet(
            columns: resolvedColumns,
            rows: primaryPreviewRows,
            totalRowCount: primaryRowCount,
            additionalResults: additionalResults
        )
    }

    // MARK: - Non-Streaming Conversion

    private func convertSQLServerRowsToEcho(_ rows: [SQLServerRow]) -> QueryResultSet {
        var echoColumns: [ColumnInfo] = []
        var echoRows: [[String?]] = []

        if let firstRow = rows.first {
            echoColumns = firstRow.columnMetadata.map { column in
                ColumnInfo(
                    name: column.colName,
                    dataType: column.typeName,
                    isPrimaryKey: false,
                    isNullable: true,
                    maxLength: column.normalizedLength
                )
            }

            echoRows = rows.map { row in
                row.values.map { $0.isNull ? nil : $0.description }
            }
        }

        return QueryResultSet(
            columns: echoColumns,
            rows: echoRows,
            totalRowCount: echoRows.count,
            commandTag: nil
        )
    }
}

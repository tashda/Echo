import Foundation
import SQLServerKit

extension MSSQLDedicatedQuerySession {
    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        let connection = try await readyConnection()
        // No fixed time limit (round 22, TO1 with the Postgres decision TD2:
        // no limit unless set). Cancelling the task cancels the statement on
        // the server and keeps the session.
        let executionResult = try await runRecoveringLostConnection { try await connection.execute(sql) }
        var queryResult = convertSQLServerRowsToEcho(executionResult.rows)
        if let raw = connection.decodeLastSensitivityClassification() {
            queryResult.dataClassification = extractClassification(from: raw, columnCount: queryResult.columns.count)
        }
        queryResult.serverMessages = executionResult.echoServerMessages()
        return queryResult
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if QueryStatementClassifier.isLikelyMessageOnlyStatement(sql, databaseType: .microsoftSQL) {
            return try await simpleQuery(sql)
        }
        guard let progressHandler else {
            return try await simpleQuery(sql)
        }
        return try await runRecoveringLostConnection {
            try await streamQueryWithProgress(sql, progressHandler: progressHandler)
        }
    }

    func simpleQuery(
        _ sql: String,
        executionMode: ResultStreamingExecutionMode?,
        progressHandler: QueryProgressHandler?
    ) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: progressHandler)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let connection = try await readyConnection()
        let rows = try await connection.queryPaged(sql, limit: limit, offset: offset)
        return convertSQLServerRowsToEcho(rows)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let connection = try await readyConnection()
        return Int(try await connection.execute(sql).rowCount ?? 0)
    }

    func executeUpdatesAtomically(_ statements: [String]) async throws {
        guard !statements.isEmpty else { return }

        let connection = try await readyConnection()
        try await connection.withTransaction { transactionConnection in
            for statement in statements {
                _ = try await transactionConnection.execute(statement)
            }
        }
    }

    private func streamQueryWithProgress(
        _ sql: String,
        progressHandler: @escaping QueryProgressHandler
    ) async throws -> QueryResultSet {
        let connection = try await readyConnection()
        let operationStart = CFAbsoluteTimeGetCurrent()
        let initialPreviewBatch = 200
        let maxFlushLatency: TimeInterval = 0.015
        let batchEnqueueSize = 512

        let bridgedHandler: QueryProgressHandler = { update in
            Task { @MainActor in
                progressHandler(update)
            }
        }

        let stream = connection.streamQuery(sql)
        var resultSetIndex = -1
        var primaryColumns: [ColumnInfo] = []
        var primaryPreviewRows: [[String?]] = []
        primaryPreviewRows.reserveCapacity(initialPreviewBatch)
        var primaryRowCount = 0
        var worker: ResultStreamBatchWorker?
        var pendingPayloads: [ResultStreamBatchWorker.Payload] = []
        pendingPayloads.reserveCapacity(batchEnqueueSize)
        var additionalResults: [QueryResultSet] = []
        var currentAdditionalColumns: [ColumnInfo] = []
        var currentAdditionalRows: [[String?]] = []
        // Every message of the batch in order (EM1): PRINT and informational messages, then errors.
        var serverMessages: [SQLServerStreamMessage] = []

        for try await event in stream {
            switch event {
            case .metadata(let columnDescriptions):
                if resultSetIndex > 0 && !currentAdditionalColumns.isEmpty {
                    additionalResults.append(
                        QueryResultSet(
                            columns: currentAdditionalColumns,
                            rows: currentAdditionalRows,
                            totalRowCount: currentAdditionalRows.count
                        )
                    )
                }

                resultSetIndex += 1
                let columns = columnDescriptions.map { column in
                    ColumnInfo(
                        name: column.name,
                        dataType: column.typeName,
                        isPrimaryKey: false,
                        isNullable: (column.flags & 0x01) != 0,
                        maxLength: column.length > 0 ? column.length : nil,
                        wireType: column.cellType.encoded
                    )
                }

                if resultSetIndex == 0 {
                    primaryColumns = columns
                    worker = ResultStreamBatchWorker(
                        label: "dev.echodb.echo.mssql.streamWorker",
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
                if resultSetIndex == 0 {
                    primaryRowCount += 1

                    // Every row, preview rows included, is spooled as wire bytes (zero-copy
                    // buffer references); the spool formats them with the driver's
                    // SQLServerCellFormatter from the column's wireType, exactly like the
                    // preview strings below (round 22, DF1).
                    var previewValues: [String?]?
                    if primaryRowCount <= initialPreviewBatch {
                        let stringValues = row.toStringArray()
                        primaryPreviewRows.append(stringValues)
                        previewValues = stringValues
                    }
                    let (buffers, lengths, totalLength) = row.rawColumnBuffers()
                    pendingPayloads.append(
                        ResultStreamBatchWorker.Payload(
                            previewValues: previewValues,
                            storage: .raw(ResultStreamBatchWorker.RawRow(
                                buffers: buffers,
                                lengths: lengths,
                                totalLength: totalLength
                            )),
                            totalRowCount: primaryRowCount,
                            decodeDuration: 0
                        )
                    )

                    if pendingPayloads.count >= batchEnqueueSize {
                        worker?.enqueueBatch(pendingPayloads)
                        pendingPayloads.removeAll(keepingCapacity: true)
                    }
                } else {
                    currentAdditionalRows.append(row.toStringArray())
                }

            case .message(let message):
                serverMessages.append(message)

            case .done:
                break
            }
        }

        if resultSetIndex > 0 && !currentAdditionalColumns.isEmpty {
            additionalResults.append(
                QueryResultSet(
                    columns: currentAdditionalColumns,
                    rows: currentAdditionalRows,
                    totalRowCount: currentAdditionalRows.count
                )
            )
        }

        // The driver's structured error keeps number, severity, line, procedure and every
        // message of the batch (round 22, errors); SQLServerFailure reads them back.
        if let failure = SQLServerError.fromServerMessages(serverMessages) {
            throw DatabaseError.from(sqlServerError: failure)
        }

        if !pendingPayloads.isEmpty {
            worker?.enqueueBatch(pendingPayloads)
        }

        if let worker {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                worker.finish(totalRowCount: primaryRowCount) {
                    Task { @MainActor in
                        continuation.resume()
                    }
                }
            }
        }

        let resolvedColumns = primaryColumns.isEmpty
            ? [ColumnInfo(name: "result", dataType: "text")]
            : primaryColumns

        return QueryResultSet(
            columns: resolvedColumns,
            rows: primaryPreviewRows,
            totalRowCount: primaryRowCount,
            additionalResults: additionalResults,
            dataClassification: extractClassification(
                from: connection.decodeLastSensitivityClassification(),
                columnCount: primaryColumns.count
            ),
            serverMessages: serverMessages.map(\.echoServerMessage)
        )
    }

    fileprivate func extractClassification(
        from raw: SQLServerSensitivityClassification?,
        columnCount: Int
    ) -> DataClassification? {
        guard let raw else { return nil }
        let labels = raw.labels.map { SensitivityLabel(name: $0.name, id: $0.id) }
        let infoTypes = raw.informationTypes.map { InformationType(name: $0.name, id: $0.id) }
        var columnMap: [Int: ColumnSensitivity] = [:]
        for (index, columnSensitivity) in raw.columns.enumerated() where index < columnCount {
            guard let property = columnSensitivity.properties.first else { continue }
            let label = property.label.map { SensitivityLabel(name: $0.name, id: $0.id) }
            let infoType = property.informationType.map { InformationType(name: $0.name, id: $0.id) }
            let rank = property.rank.map { SensitivityRank(rawValue: $0.rawValue) ?? .notDefined }
            columnMap[index] = ColumnSensitivity(label: label, informationType: infoType, rank: rank)
        }
        guard !columnMap.isEmpty else { return nil }
        let overallRank = raw.rank.map { SensitivityRank(rawValue: $0.rawValue) ?? .notDefined }
        return DataClassification(labels: labels, informationTypes: infoTypes, columns: columnMap, overallRank: overallRank)
    }

    fileprivate func convertSQLServerRowsToEcho(_ rows: [SQLServerRow]) -> QueryResultSet {
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

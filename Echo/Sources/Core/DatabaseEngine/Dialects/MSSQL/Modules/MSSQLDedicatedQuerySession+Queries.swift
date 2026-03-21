import Foundation
import SQLServerKit

extension MSSQLDedicatedQuerySession {
    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        let connection = try await readyConnection()
        let executionResult = try await connection.execute(sql)
        var queryResult = convertSQLServerRowsToEcho(executionResult.rows)
        if let raw = connection.decodeLastSensitivityClassification() {
            queryResult.dataClassification = extractClassification(from: raw, columnCount: queryResult.columns.count)
        }
        queryResult.serverMessages = executionResult.messages
            .filter { $0.kind == .info }
            .map { message in
                ServerMessage(
                    kind: .info,
                    number: message.number,
                    message: message.message,
                    state: message.state,
                    severity: message.severity
                )
            }
        return queryResult
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        guard let progressHandler else {
            return try await simpleQuery(sql)
        }
        return try await streamQueryWithProgress(sql, progressHandler: progressHandler)
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
        var errorMessage: SQLServerStreamMessage?
        var infoMessages: [SQLServerStreamMessage] = []

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
                        maxLength: column.length > 0 ? column.length : nil
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
                let stringValues = row.values.map { value in
                    value.isNull ? nil : value.description
                }

                if resultSetIndex == 0 {
                    primaryRowCount += 1
                    pendingPayloads.append(
                        ResultStreamBatchWorker.Payload(
                            previewValues: primaryRowCount <= initialPreviewBatch ? stringValues : nil,
                            storage: .stringValues(stringValues),
                            totalRowCount: primaryRowCount,
                            decodeDuration: 0
                        )
                    )

                    if primaryRowCount <= initialPreviewBatch {
                        primaryPreviewRows.append(stringValues)
                    }

                    if pendingPayloads.count >= batchEnqueueSize {
                        worker?.enqueueBatch(pendingPayloads)
                        pendingPayloads.removeAll(keepingCapacity: true)
                    }
                } else {
                    currentAdditionalRows.append(stringValues)
                }

            case .message(let message):
                if message.kind == .error {
                    errorMessage = message
                } else {
                    infoMessages.append(message)
                }

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

        if let errorMessage {
            throw DatabaseError.queryError(errorMessage.message)
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
            serverMessages: infoMessages.map { message in
                ServerMessage(
                    kind: .info,
                    number: message.number,
                    message: message.message,
                    state: message.state,
                    severity: message.severity
                )
            }
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

import Foundation
import SQLServerKit
import OSLog

extension SQLServerSessionAdapter {
    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        let result = try await client.withConnection { connection in
            let execResult = try await connection.execute(sql)
            let classification = connection.decodeLastSensitivityClassification()
            return (execResult: execResult, classification: classification)
        }
        var queryResult = convertSQLServerRowsToEcho(result.execResult.rows)
        if let raw = result.classification {
            queryResult.dataClassification = extractClassification(from: raw, columnCount: queryResult.columns.count)
        }
        queryResult.serverMessages = result.execResult.messages
            .filter { $0.kind == .info }
            .map { msg in
                ServerMessage(
                    kind: .info,
                    number: msg.number,
                    message: msg.message,
                    state: msg.state,
                    severity: msg.severity
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
        if ifExists {
            _ = try await simpleQuery("IF OBJECT_ID('[\(schema ?? "dbo")].[\(name)]', 'U') IS NOT NULL DROP TABLE [\(schema ?? "dbo")].[\(name)]")
        } else {
            try await client.admin.dropTable(
                name: name,
                schema: schema ?? "dbo",
                database: database
            )
        }
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
            Task { @MainActor in
                progressHandler(update)
            }
        }

        return try await client.withConnection { [self] connection in
            let stream = connection.streamQuery(sql)

            // Track which result set we're on (0 = primary, 1+ = additional)
            var resultSetIndex = -1

            // Primary result set state (streamed progressively)
            var primaryColumns: [ColumnInfo] = []
            var canUseRawPath = true
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
            var infoMessages: [SQLServerStreamMessage] = []

            for try await event in stream {
                try Task.checkCancellation()

                switch event {
                case .metadata(let columnDescriptions):
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
                            dataType: col.typeName,
                            isPrimaryKey: false,
                            isNullable: (col.flags & 0x01) != 0,
                            maxLength: col.length > 0 ? col.length : nil
                        )
                    }

                    if resultSetIndex == 0 {
                        primaryColumns = columns
                        canUseRawPath = columns.allSatisfy { TDSBinaryDecoder.canDecodeRaw($0.dataType) }
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
                    if resultSetIndex == 0 {
                        primaryRowCount += 1

                        if primaryRowCount <= initialPreviewBatch {
                            let stringValues = row.toStringArray()
                            primaryPreviewRows.append(stringValues)
                            pendingPayloads.append(ResultStreamBatchWorker.Payload(
                                previewValues: stringValues,
                                storage: .stringValues(stringValues),
                                totalRowCount: primaryRowCount,
                                decodeDuration: 0
                            ))
                        } else if canUseRawPath {
                            let (buffers, lengths, totalLength) = row.rawColumnBuffers()
                            pendingPayloads.append(ResultStreamBatchWorker.Payload(
                                previewValues: nil,
                                storage: .raw(ResultStreamBatchWorker.RawRow(
                                    buffers: buffers,
                                    lengths: lengths,
                                    totalLength: totalLength
                                )),
                                totalRowCount: primaryRowCount,
                                decodeDuration: 0
                            ))
                        } else {
                            let stringValues = row.toStringArray()
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
                            self.logger.debug("[MSSQLStream] first-row latency=\(String(format: "%.3f", latency))s")
                        }
                    } else {
                        currentAdditionalRows.append(row.toStringArray())
                    }

                case .message(let msg):
                    if msg.kind == .error {
                        errorMessage = msg
                    } else {
                        infoMessages.append(msg)
                    }

                case .done:
                    break
                }
            }

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
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }

            let classification = self.extractClassification(from: connection, columnCount: primaryColumns.count)
            let totalElapsed = CFAbsoluteTimeGetCurrent() - operationStart
            self.logger.debug("[MSSQLStream] completed sets=\(resultSetIndex + 1) primaryRows=\(primaryRowCount) additionalSets=\(additionalResults.count) elapsed=\(String(format: "%.3f", totalElapsed))s")

            let resolvedColumns = primaryColumns.isEmpty
                ? [ColumnInfo(name: "result", dataType: "text")]
                : primaryColumns

            let serverMessages = infoMessages.map { msg in
                ServerMessage(
                    kind: .info,
                    number: msg.number,
                    message: msg.message,
                    state: msg.state,
                    severity: msg.severity
                )
            }

            return QueryResultSet(
                columns: resolvedColumns,
                rows: primaryPreviewRows,
                totalRowCount: primaryRowCount,
                additionalResults: additionalResults,
                dataClassification: classification,
                serverMessages: serverMessages
            )
        }
    }

    // MARK: - Classification Extraction

    private func extractClassification(
        from connection: SQLServerConnection,
        columnCount: Int
    ) -> DataClassification? {
        guard let raw = connection.decodeLastSensitivityClassification() else { return nil }
        return extractClassification(from: raw, columnCount: columnCount)
    }

    private func extractClassification(
        from raw: SQLServerSensitivityClassification,
        columnCount: Int
    ) -> DataClassification? {
        let labels = raw.labels.map { SensitivityLabel(name: $0.name, id: $0.id) }
        let infoTypes = raw.informationTypes.map { InformationType(name: $0.name, id: $0.id) }
        var columnMap: [Int: ColumnSensitivity] = [:]
        for (index, colSensitivity) in raw.columns.enumerated() where index < columnCount {
            guard let prop = colSensitivity.properties.first else { continue }
            let label = prop.label.map { SensitivityLabel(name: $0.name, id: $0.id) }
            let infoType = prop.informationType.map { InformationType(name: $0.name, id: $0.id) }
            let rank = prop.rank.map { SensitivityRank(rawValue: $0.rawValue) ?? .notDefined }
            columnMap[index] = ColumnSensitivity(label: label, informationType: infoType, rank: rank)
        }
        guard !columnMap.isEmpty else { return nil }
        let overallRank = raw.rank.map { SensitivityRank(rawValue: $0.rawValue) ?? .notDefined }
        return DataClassification(labels: labels, informationTypes: infoTypes, columns: columnMap, overallRank: overallRank)
    }

    // MARK: - Non-Streaming Conversion

    func convertSQLServerRowsToEcho(_ rows: [SQLServerRow]) -> QueryResultSet {
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

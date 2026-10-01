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

    /// Off the main actor, like Postgres's streaming: the query tab awaits this from the main
    /// actor, and a nonisolated async function runs on its caller's actor (SE-0461), so every
    /// row was read and handed to the batch worker on the main thread while results streamed in,
    /// stalling scrolling for up to a quarter of a second (traced 2026-10-01).
    @concurrent
    private func streamQueryWithProgress(
        _ sql: String,
        progressHandler: @escaping QueryProgressHandler
    ) async throws -> QueryResultSet {
        let connection = try await readyConnection()
        let operationStart = CFAbsoluteTimeGetCurrent()
        let bridgedHandler: QueryProgressHandler = { update in
            Task { @MainActor in
                progressHandler(update)
            }
        }

        let stream = connection.streamQuery(sql)
        var primary: SQLServerResultSetSink?
        var current: SQLServerResultSetSink?
        var resultSetCount = 0
        var additionalResults: [QueryResultSet] = []
        // Every message of the batch in order (EM1): PRINT and informational messages, then errors.
        var serverMessages: [SQLServerStreamMessage] = []

        for try await event in stream {
            switch event {
            case .metadata(let columnDescriptions):
                if let current, current !== primary {
                    additionalResults.append(await current.finish())
                }
                let sink = SQLServerResultSetSink(
                    columnDescriptions: columnDescriptions,
                    resultSetIndex: resultSetCount,
                    operationStart: operationStart,
                    progressHandler: bridgedHandler
                )
                resultSetCount += 1
                if primary == nil { primary = sink }
                current = sink

            case .row(let row):
                current?.append(row)

            case .message(let message):
                serverMessages.append(message)

            case .done:
                break
            }
        }

        if let current, current !== primary {
            additionalResults.append(await current.finish())
        }

        // The driver's structured error keeps number, severity, line, procedure and every
        // message of the batch (round 22, errors); SQLServerFailure reads them back.
        if let failure = SQLServerError.fromServerMessages(serverMessages) {
            throw DatabaseError.from(sqlServerError: failure)
        }

        let first = await primary?.finish()
        let columns = first?.columns ?? []
        return QueryResultSet(
            columns: columns.isEmpty ? [ColumnInfo(name: "result", dataType: "text")] : columns,
            rows: first?.rows ?? [],
            totalRowCount: first?.totalRowCount ?? 0,
            additionalResults: additionalResults,
            dataClassification: extractClassification(
                from: connection.decodeLastSensitivityClassification(),
                columnCount: columns.count
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
                    maxLength: column.normalizedLength,
                    encryption: ColumnInfo.Encryption(column.encryption)
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

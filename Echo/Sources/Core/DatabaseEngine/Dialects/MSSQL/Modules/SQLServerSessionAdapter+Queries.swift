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
        queryResult.serverMessages = result.execResult.echoServerMessages()
        return queryResult
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if QueryStatementClassifier.isLikelyMessageOnlyStatement(sql, databaseType: .microsoftSQL) {
            return try await simpleQuery(sql)
        }
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

    func executeUpdatesAtomically(_ statements: [String]) async throws {
        guard !statements.isEmpty else { return }

        try await client.transactions.executeInTransaction {
            for statement in statements {
                _ = try await self.client.execute(statement)
            }
        }
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
            database: database,
            ifExists: ifExists
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
        let bridgedHandler: QueryProgressHandler = { update in
            Task { @MainActor in
                progressHandler(update)
            }
        }

        return try await client.withConnection { [self] connection in
            let stream = connection.streamQuery(sql)
            // One sink per result set; extra sets stream into their own results (round 22, BG1).
            var primary: SQLServerResultSetSink?
            var current: SQLServerResultSetSink?
            var resultSetCount = 0
            var additionalResults: [QueryResultSet] = []
            // Every message of the batch in order (EM1): PRINT and informational messages, then errors.
            var streamMessages: [SQLServerStreamMessage] = []

            for try await event in stream {
                try Task.checkCancellation()

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

                case .message(let msg):
                    streamMessages.append(msg)

                case .done:
                    break
                }
            }

            if let current, current !== primary {
                additionalResults.append(await current.finish())
            }

            // The driver's structured error keeps number, severity, line, procedure and every
            // message of the batch (round 22, errors); SQLServerFailure reads them back.
            if let failure = SQLServerError.fromServerMessages(streamMessages) {
                throw DatabaseError.from(sqlServerError: failure)
            }

            let first = await primary?.finish()
            let columns = first?.columns ?? []
            let classification = self.extractClassification(from: connection, columnCount: columns.count)
            let totalElapsed = CFAbsoluteTimeGetCurrent() - operationStart
            self.logger.debug("[MSSQLStream] completed sets=\(resultSetCount) primaryRows=\(first?.totalRowCount ?? 0) additionalSets=\(additionalResults.count) elapsed=\(String(format: "%.3f", totalElapsed))s")

            return QueryResultSet(
                columns: columns.isEmpty ? [ColumnInfo(name: "result", dataType: "text")] : columns,
                rows: first?.rows ?? [],
                totalRowCount: first?.totalRowCount ?? 0,
                additionalResults: additionalResults,
                dataClassification: classification,
                serverMessages: streamMessages.map(\.echoServerMessage)
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

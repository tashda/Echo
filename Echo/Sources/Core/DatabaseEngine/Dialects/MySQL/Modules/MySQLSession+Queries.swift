import Foundation
import Logging
import MySQLKit

extension MySQLSession {
    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if QueryStatementClassifier.isLikelyMessageOnlyStatement(sql, databaseType: .mysql) {
            return try await executeSimpleQuery(sql)
        }

        guard let progressHandler else {
            return try await executeSimpleQuery(sql)
        }

        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(512)
        var totalRowCount = 0

        let operationStart = CFAbsoluteTimeGetCurrent()
        let streamingPreviewLimit = 512
        let maxFlushLatency: TimeInterval = 0.015

        var columns: [MySQLColumn] = []
        var columnInfo: [ColumnInfo] = []
        var messages: [ServerMessage] = []
        var worker: ResultStreamBatchWorker?
        let bridgedHandler: QueryProgressHandler = { update in
            Task { @MainActor in
                progressHandler(update)
            }
        }

        do {
            // Rows are pulled from the server as the worker takes them (bounded memory); Cancel
            // stops the statement on the server (KILL QUERY).
            for try await event in try await client.events(sql) {
                try Task.checkCancellation()
                switch event {
                case .columns(let resultColumns):
                    // The first result set fills the grid; later ones (multi-statement) only report.
                    guard columns.isEmpty else { continue }
                    columns = resultColumns
                    columnInfo = Self.columnInfo(for: resultColumns)
                    worker = ResultStreamBatchWorker(
                        label: "dev.echodb.echo.mysql.streamWorker",
                        columns: columnInfo,
                        streamingPreviewLimit: streamingPreviewLimit,
                        maxFlushLatency: maxFlushLatency,
                        operationStart: operationStart,
                        progressHandler: bridgedHandler
                    )
                case .rows(let rows):
                    guard let first = rows.first, first.columnDefinitions == columns else { continue }
                    var payloads: [ResultStreamBatchWorker.Payload] = []
                    payloads.reserveCapacity(rows.count)
                    for row in rows {
                        let decodeStart = CFAbsoluteTimeGetCurrent()
                        let values = columns.indices.map { index in
                            formatter.stringValue(bytes: row.value(at: index).bytes, column: columns[index])
                        }
                        totalRowCount += 1
                        let capturePreview = totalRowCount <= streamingPreviewLimit
                        if capturePreview { previewRows.append(values) }
                        // The spool keeps the display text, so spooled rows read like the preview.
                        let encodedRow = ResultBinaryRowCodec.encodeRaw(cells: values.map { $0.map { Data($0.utf8) } })
                        payloads.append(ResultStreamBatchWorker.Payload(
                            previewValues: capturePreview ? values : nil,
                            storage: .encoded(encodedRow),
                            totalRowCount: totalRowCount,
                            decodeDuration: CFAbsoluteTimeGetCurrent() - decodeStart
                        ))
                    }
                    worker?.enqueueBatch(payloads)
                case .done(let metadata, let returnedRows):
                    messages.append(Self.serverMessage(Self.commandResponse(metadata, returnedRows: returnedRows)))
                case .warnings(let warnings):
                    // Echo #39: warnings and notes in Messages.
                    messages.append(contentsOf: warnings.map(Self.serverMessage(for:)))
                }
            }
        } catch is CancellationError {
            worker?.finish(totalRowCount: totalRowCount)
            throw CancellationError()
        } catch {
            worker?.finish(totalRowCount: totalRowCount)
            throw DatabaseError.queryError(error.localizedDescription)
        }

        if let worker {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                worker.finish(totalRowCount: totalRowCount) {
                    Task { @MainActor in continuation.resume() }
                }
            }
        }
        let resolvedColumns = columnInfo.isEmpty ? [ColumnInfo(name: "result", dataType: "text")] : columnInfo
        return QueryResultSet(columns: resolvedColumns, rows: previewRows, totalRowCount: totalRowCount, serverMessages: messages)
    }

    /// Stops what this connection runs, on the server (Echo #33).
    func cancelRunningQuery() async -> Bool {
        do {
            try await client.cancelRunningStatement()
            return true
        } catch {
            logger.warning("MySQL cancel failed: \(error.localizedDescription)")
            return false
        }
    }

    func simpleQuery(
        _ sql: String,
        executionMode: ResultStreamingExecutionMode?,
        progressHandler: QueryProgressHandler?
    ) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: progressHandler)
    }

    private func executeSimpleQuery(_ sql: String) async throws -> QueryResultSet {
        do {
            let result = try await client.query(sql)
            return makeResultSet(from: result)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let pagedSQL = "\(sql) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func listDatabases() async throws -> [String] {
        try await client.metadata.listDatabases()
    }

    func listSchemas() async throws -> [String] {
        if let current = try await currentDatabaseName() {
            return [current]
        }
        if let defaultDatabase, !defaultDatabase.isEmpty {
            return [defaultDatabase]
        }
        return []
    }

    public func currentDatabaseName() async throws -> String? {
        try await client.session.currentDatabase()
    }

    @discardableResult
    internal func performQuery(_ sql: String, binds: [MySQLData] = []) async throws -> ([MySQLRow], MySQLWireQueryMetadata?) {
        let result = try await client.query(sql, binds: binds)
        return (result.rows, result.metadata)
    }

    /// Grid columns with MySQL's SQL type names (`BIGINT UNSIGNED`, `DECIMAL(10,2)`), so numbers
    /// align and the header says what the column is (Echo #40).
    static func columnInfo(for columns: [MySQLColumn]) -> [ColumnInfo] {
        columns.map { column in
            ColumnInfo(
                name: column.name,
                dataType: column.sqlTypeName,
                isPrimaryKey: column.flags.contains(.primaryKey),
                isNullable: !column.flags.contains(.notNull),
                maxLength: column.columnLength == 0 ? nil : Int(column.columnLength)
            )
        }
    }

    static func serverMessage(_ text: String) -> ServerMessage {
        ServerMessage(kind: .info, number: 0, message: text, state: 0, severity: 0, category: "Server Response")
    }

    static func serverMessage(for warning: MySQLWarning) -> ServerMessage {
        ServerMessage(kind: warning.level.lowercased() == "error" ? .error : .info, number: Int32(clamping: warning.code),
                      message: warning.message, state: 0, severity: 0, category: warning.level)
    }

    /// "3 rows affected" or "2 rows returned", with MySQL's info text when it has one.
    static func commandResponse(_ metadata: MySQLWireQueryMetadata, returnedRows: Bool) -> String {
        let count = metadata.affectedRows
        var text = returnedRows ? "\(count) row\(count == 1 ? "" : "s") returned" : "\(count) row\(count == 1 ? "" : "s") affected"
        if let info = metadata.info, !info.isEmpty { text += " (\(info))" }
        return text
    }

    private func makeResultSet(from result: MySQLWireQueryResult) -> QueryResultSet {
        let columns = result.columns
        let previewRows = result.rows.map { row in
            columns.indices.map { formatter.stringValue(bytes: row.value(at: $0).bytes, column: columns[$0]) }
        }
        return QueryResultSet(
            columns: Self.columnInfo(for: columns),
            rows: previewRows,
            totalRowCount: result.rows.count,
            commandTag: result.metadata.map(commandResponse(from:))
        )
    }

    private func commandResponse(from metadata: MySQLWireQueryMetadata) -> String {
        var segments = ["affectedRows=\(metadata.affectedRows)"]
        if let lastInsertID = metadata.lastInsertID {
            segments.append("lastInsertID=\(lastInsertID)")
        }
        return segments.joined(separator: ", ")
    }
}

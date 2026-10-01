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
        return try await streamQuery(sql, progressHandler: progressHandler)
    }

    /// Off the main actor, like PostgreSQL's and SQL Server's streaming: a nonisolated async
    /// function runs on its caller's actor (SE-0461), and the tab calls from the main actor.
    /// Rows are pulled from the server as the workers take them (bounded memory); each result set
    /// gets its own grid.
    @concurrent
    private func streamQuery(_ sql: String, progressHandler: @escaping QueryProgressHandler) async throws -> QueryResultSet {
        let operationStart = CFAbsoluteTimeGetCurrent()
        let bridgedHandler: QueryProgressHandler = { update in
            Task { @MainActor in
                progressHandler(update)
            }
        }
        var current: MySQLResultSetSink?
        var results: [QueryResultSet] = []
        var messages: [ServerMessage] = []
        do {
            for try await event in try await client.events(sql) {
                try Task.checkCancellation()
                switch event {
                case .columns(let columns):
                    if let previous = current { results.append(await previous.finish()) }
                    current = MySQLResultSetSink(
                        columns: columns,
                        resultSetIndex: results.count,
                        formatter: formatter,
                        operationStart: operationStart,
                        progressHandler: bridgedHandler
                    )
                case .rows(let rows):
                    current?.append(rows)
                case .done(let metadata, let returnedRows):
                    messages.append(Self.serverMessage(Self.commandResponse(metadata, returnedRows: returnedRows)))
                case .warnings(let warnings):
                    // Echo #39: warnings and notes in Messages.
                    messages.append(contentsOf: warnings.map(Self.serverMessage(for:)))
                }
            }
        } catch is CancellationError {
            current?.abandon()
            throw CancellationError()
        } catch {
            current?.abandon()
            throw await queryFailure(error)
        }
        if let current { results.append(await current.finish()) }
        guard let first = results.first else {
            return QueryResultSet(columns: [ColumnInfo(name: "result", dataType: "text")], rows: [], totalRowCount: 0, serverMessages: messages)
        }
        return QueryResultSet(
            columns: first.columns,
            rows: first.rows,
            totalRowCount: first.totalRowCount,
            additionalResults: Array(results.dropFirst()),
            serverMessages: messages
        )
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

    /// Force Stop (round 21, CS2): closes the connection still running a statement after a KILL
    /// QUERY the server did not answer. The next run opens a new connection.
    func forceStopRunningQuery() async -> (stopped: Bool, transactionWasOpen: Bool) {
        let outcome = await client.closeRunningConnection()
        return (outcome.closed, outcome.transactionWasOpen)
    }

    /// Whether a transaction is open, as of the last statement (no round trip).
    var isInTransaction: Bool {
        get async { await client.isInTransaction }
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
            throw await queryFailure(error)
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

import Foundation
import PostgresKit
import PostgresWire

extension PostgresSession {

    /// Runs a script statement by statement (PostgresNIO executes one statement per query). Each
    /// statement is one "batch" in Echo's multi-batch results. All statements run on one connection —
    /// the tab's pinned connection, or a single leased pool connection — so `BEGIN … COMMIT` and `SET`
    /// span the script. Like psql's default, a failed statement is reported and the script continues.
    func executeBatches(_ batches: [String], progressHandler: BatchProgressHandler?) async throws -> [BatchResult] {
        if let pinned = try await pinnedSessionForBatches() {
            return try await runStatements(batches, progressHandler: progressHandler) { sql in
                PostgresSQLSplitter.returnsRows(sql)
                    ? .rows(try await pinned.query(sql).collect())
                    : .command(try await pinned.queryResult(sql))
            }
        }
        return try await client.withConnection { connection in
            try await self.runStatements(batches, progressHandler: progressHandler) { sql in
                PostgresSQLSplitter.returnsRows(sql)
                    ? .rows(try await connection.simpleQuery(sql).collect())
                    : .command(try await connection.queryResult(sql))
            }
        }
    }

    /// Cancels, on the server, whatever this tab is running. Only query-tab sessions know their
    /// backend; returns whether a cancel was sent.
    func cancelRunningQuery() async -> Bool {
        guard let pinnedStore else { return false }
        return await pinnedStore.cancelRunning(using: client)
    }

    // MARK: - Internals

    private enum StatementOutput {
        case rows([PostgresRow])
        case command(WireQueryResult)
    }

    private func pinnedSessionForBatches() async throws -> PostgresSessionConnection? {
        do {
            return try await pinnedSession()
        } catch {
            throw normalizeError(error)
        }
    }

    private func runStatements(
        _ statements: [String],
        progressHandler: BatchProgressHandler?,
        execute: (String) async throws -> StatementOutput
    ) async throws -> [BatchResult] {
        let formatter = PostgresCellFormatter()
        var results: [BatchResult] = []
        for (index, raw) in statements.enumerated() {
            try Task.checkCancellation()
            let sql = sanitizeSQL(raw)
            progressHandler?(BatchProgressUpdate(batchIndex: index, batchCount: statements.count, event: .started))
            do {
                switch try await execute(sql) {
                case .rows(let rows):
                    let columns = rows.first.map { row in
                        PostgresRowExtractor.columns(from: row).map {
                            ColumnInfo(name: $0.name, dataType: $0.dataType, isPrimaryKey: false, isNullable: true, maxLength: nil)
                        }
                    } ?? []
                    let values = rows.map { row in row.map { formatter.stringValue(for: $0) } }
                    let set = QueryResultSet(columns: columns.isEmpty ? [ColumnInfo(name: "result", dataType: "text")] : columns, rows: values, totalRowCount: values.count)
                    let message = ServerMessage(kind: .info, number: 0, message: "\(values.count) row\(values.count == 1 ? "" : "s")", state: 0, severity: 0, serverName: nil, procedureName: nil, lineNumber: nil, category: "Server Response", metadata: [:])
                    results.append(BatchResult(batchIndex: index, resultSets: [set], error: nil, messages: [message]))
                case .command(let result):
                    var tag = result.metadata.command
                    if let oid = result.metadata.oid { tag += " \(oid)" }
                    if let rows = result.metadata.rows { tag += " \(rows)" }
                    let message = ServerMessage(kind: .info, number: 0, message: tag, state: 0, severity: 0, serverName: nil, procedureName: nil, lineNumber: nil, category: "Server Response", metadata: [:])
                    results.append(BatchResult(batchIndex: index, resultSets: [], error: nil, messages: [message]))
                }
                progressHandler?(BatchProgressUpdate(batchIndex: index, batchCount: statements.count, event: .completed))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let message = normalizeError(error, contextSQL: sql).localizedDescription
                results.append(BatchResult(batchIndex: index, resultSets: [], error: message, messages: []))
                progressHandler?(BatchProgressUpdate(batchIndex: index, batchCount: statements.count, event: .failed(message)))
            }
        }
        return results
    }
}

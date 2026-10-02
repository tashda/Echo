import Foundation
import PostgresKit

/// How a PostgreSQL script runs (Echo Labs round 21, script results: E3 and OT1).
struct PostgresScriptOptions: Sendable, Equatable {
    /// Stop at the first failed statement; the rest are reported as not run. Off only when the
    /// "Continue a script after a failed statement" setting is on.
    var stopOnError = true
    /// Run the whole script inside one transaction: all of it or none of it.
    var asOneTransaction = false
}

/// What happened to the one transaction around a script, when one was asked for.
enum PostgresScriptTransaction: Sendable, Equatable {
    case notRequested
    case committed
    case rolledBack(failedStatement: Int)
    /// The script has its own BEGIN, COMMIT or ROLLBACK, so it ran as written.
    case scriptManagesItsOwn
}

struct PostgresScriptRun: Sendable {
    let results: [BatchResult]
    let transaction: PostgresScriptTransaction
}

extension PostgresSession {

    /// Runs a script statement by statement (PostgresNIO executes one statement per query). Each
    /// statement is one "batch" in Echo's multi-batch results. All statements run on one connection —
    /// the tab's pinned connection, or a single leased pool connection — so `BEGIN … COMMIT` and `SET`
    /// span the script.
    func executeBatches(_ batches: [String], progressHandler: BatchProgressHandler?) async throws -> [BatchResult] {
        try await executeScript(batches, options: PostgresScriptOptions(), progressHandler: progressHandler).results
    }

    func executeScript(_ statements: [String], options: PostgresScriptOptions, progressHandler: BatchProgressHandler?) async throws -> PostgresScriptRun {
        if let pinned = try await pinnedSessionForBatches() {
            return try await runStatements(statements, options: options, progressHandler: progressHandler, notices: {
                await pinned.takeNotices()
            }) { sql in
                guard PostgresSQLSplitter.returnsRows(sql) else { return .command(try await pinned.queryResult(sql)) }
                let rows = try await pinned.query(sql)
                let collected = try await rows.collect()
                return .rows(try await rows.columns(), collected)
            }
        }
        return try await client.withConnection { connection in
            try await self.runStatements(statements, options: options, progressHandler: progressHandler, notices: {
                await connection.takeNotices()
            }) { sql in
                guard PostgresSQLSplitter.returnsRows(sql) else { return .command(try await connection.queryResult(sql)) }
                let rows = try await connection.simpleQuery(sql)
                let collected = try await rows.collect()
                return .rows(try await rows.columns(), collected)
            }
        }
    }

    /// Cancels, on the server, whatever this tab is running. Only query-tab sessions know their
    /// backend; returns whether a cancel was sent.
    func cancelRunningQuery() async -> Bool {
        guard let pinnedStore else { return false }
        return await pinnedStore.cancelRunning(using: client)
    }

    /// Force Stop: closes the tab's connection that is still running a statement.
    func forceStopRunningQuery() async -> (stopped: Bool, transactionWasOpen: Bool) {
        guard let pinnedStore else { return (false, false) }
        return await pinnedStore.forceStopRunning()
    }

    /// The tab's transaction state for this session's database (nil outside query tabs).
    func pinnedTransactionStatus() async -> PostgresTransactionStatus? {
        await pinnedStore?.transactionStatus(for: databaseName)
    }

    /// Whether the tab's transaction failed (a statement in it errored or was cancelled).
    func isInFailedTransaction() async -> Bool {
        await pinnedTransactionStatus() == .failed
    }

    // MARK: - Internals

    private enum StatementOutput {
        case rows([PostgresColumn], [PostgresRow])
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
        options: PostgresScriptOptions,
        progressHandler: BatchProgressHandler?,
        notices: () async -> [PostgresNotice],
        execute: (String) async throws -> StatementOutput
    ) async throws -> PostgresScriptRun {
        let managesOwnTransaction = statements.contains { PostgresSQLSplitter.transactionEffect(of: $0) != .none }
        let wrap = options.asOneTransaction && !managesOwnTransaction
        if wrap {
            do { _ = try await execute("BEGIN") } catch { throw normalizeError(error) }
        }

        let formatter = PostgresCellFormatter()
        var results: [BatchResult] = []
        var failedIndex: Int?
        do {
            for (index, raw) in statements.enumerated() {
                try Task.checkCancellation()
                if failedIndex != nil, options.stopOnError || wrap {
                    var skipped = BatchResult(batchIndex: index, resultSets: [], error: nil, messages: [])
                    skipped.skipped = true
                    results.append(skipped)
                    continue
                }
                let sql = sanitizeSQL(raw)
                progressHandler?(BatchProgressUpdate(batchIndex: index, batchCount: statements.count, event: .started))
                let started = ContinuousClock.now
                do {
                    var result: BatchResult
                    switch try await execute(sql) {
                    case .rows(let resultColumns, let rows):
                        let columns = await columnInfo(resultColumns)
                        let values = rows.map { row in row.map { formatter.stringValue(for: $0) } }
                        let set = QueryResultSet(columns: columns.isEmpty ? [ColumnInfo(name: "result", dataType: "text")] : columns, rows: values, totalRowCount: values.count)
                        let messages = Self.serverMessages(await notices()) + [Self.serverMessage("SELECT \(values.count)")]
                        result = BatchResult(batchIndex: index, resultSets: [set], error: nil, messages: messages)
                    case .command(let output):
                        var tag = output.metadata.command
                        if let oid = output.metadata.oid { tag += " \(oid)" }
                        if let rows = output.metadata.rows { tag += " \(rows)" }
                        let messages = Self.serverMessages(await notices()) + [Self.serverMessage(tag)]
                        result = BatchResult(batchIndex: index, resultSets: [], error: nil, messages: messages)
                    }
                    result.duration = Self.seconds(since: started)
                    results.append(result)
                    progressHandler?(BatchProgressUpdate(batchIndex: index, batchCount: statements.count, event: .completed))
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    let message = normalizeError(error, contextSQL: sql).localizedDescription
                    var failed = BatchResult(batchIndex: index, resultSets: [], error: message, messages: Self.serverMessages(await notices()))
                    failed.duration = Self.seconds(since: started)
                    results.append(failed)
                    failedIndex = failedIndex ?? index
                    progressHandler?(BatchProgressUpdate(batchIndex: index, batchCount: statements.count, event: .failed(message)))
                }
            }
        } catch {
            if wrap { _ = try? await execute("ROLLBACK") }
            throw error
        }

        guard wrap else {
            return PostgresScriptRun(results: results, transaction: options.asOneTransaction ? .scriptManagesItsOwn : .notRequested)
        }
        if let failedIndex {
            _ = try? await execute("ROLLBACK")
            return PostgresScriptRun(results: results, transaction: .rolledBack(failedStatement: failedIndex))
        }
        do { _ = try await execute("COMMIT") } catch { throw normalizeError(error) }
        return PostgresScriptRun(results: results, transaction: .committed)
    }

    private static func serverMessage(_ text: String) -> ServerMessage {
        ServerMessage(kind: .info, number: 0, message: text, state: 0, severity: 0, serverName: nil, procedureName: nil, lineNumber: nil, category: "Server Response", metadata: [:])
    }

    private static func seconds(since start: ContinuousClock.Instant) -> TimeInterval {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    }
}

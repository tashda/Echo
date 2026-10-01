import Foundation
import MySQLKit

/// A MySQL or MariaDB script, statement by statement, as PostgreSQL's (Echo Labs round 21, script
/// results; #36): one result per statement, each statement's warnings, and a stop at the first
/// failure, the rest reported as not run. All statements run on the tab's connection, so
/// transactions, `USE` and session variables span the script.
extension MySQLSession {
    func executeBatches(_ batches: [String], progressHandler: BatchProgressHandler?) async throws -> [BatchResult] {
        var results: [BatchResult] = []
        var failed = false
        for (index, statement) in batches.enumerated() {
            try Task.checkCancellation()
            guard !failed else {
                var skipped = BatchResult(batchIndex: index, resultSets: [], error: nil, messages: [])
                skipped.skipped = true
                results.append(skipped)
                continue
            }
            progressHandler?(BatchProgressUpdate(batchIndex: index, batchCount: batches.count, event: .started))
            let started = ContinuousClock.now
            do {
                var result = try await runStatement(statement, index: index)
                result.duration = Self.seconds(since: started)
                results.append(result)
                progressHandler?(BatchProgressUpdate(batchIndex: index, batchCount: batches.count, event: .completed))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let message = await queryFailure(error).localizedDescription
                var failure = BatchResult(batchIndex: index, resultSets: [], error: message, messages: [])
                failure.duration = Self.seconds(since: started)
                results.append(failure)
                failed = true
                progressHandler?(BatchProgressUpdate(batchIndex: index, batchCount: batches.count, event: .failed(message)))
            }
        }
        return results
    }

    /// One statement's result sets (a procedure can return several) and messages.
    private func runStatement(_ sql: String, index: Int) async throws -> BatchResult {
        var sets: [QueryResultSet] = []
        var columns: [MySQLColumn] = []
        var rows: [[String?]] = []
        var messages: [ServerMessage] = []
        func closeSet() {
            guard !columns.isEmpty else { return }
            sets.append(QueryResultSet(columns: Self.columnInfo(for: columns), rows: rows, totalRowCount: rows.count))
            columns = []
            rows = []
        }
        for try await event in try await client.events(sql) {
            switch event {
            case .columns(let resultColumns):
                closeSet()
                columns = resultColumns
            case .rows(let batch):
                rows += batch.map { row in columns.indices.map { formatter.stringValue(bytes: row.value(at: $0).bytes, column: columns[$0]) } }
            case .done(let metadata, let returnedRows):
                closeSet()
                messages.append(Self.serverMessage(Self.commandResponse(metadata, returnedRows: returnedRows)))
            case .warnings(let warnings):
                messages.append(contentsOf: warnings.map(Self.serverMessage(for:)))
            }
        }
        closeSet()
        return BatchResult(batchIndex: index, resultSets: sets, error: nil, messages: messages)
    }

    static func seconds(since start: ContinuousClock.Instant) -> TimeInterval {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    }
}

import Foundation
import MySQLKit

extension BulkImportViewModel {
    /// MySQL and MariaDB, like SQL Server (round 25): one transaction for the whole file, so a
    /// failure or a cancel leaves the table as it was. MySQLKit loads it with LOAD DATA LOCAL on
    /// a connection of its own when the server allows `local_infile` (decision D17), otherwise
    /// with INSERT statements. Empty cells are NULL.
    func executeMySQLImport(rows: [[String]], columns: [String]) async throws {
        guard let mysql = session as? MySQLSession else {
            throw DatabaseError.queryError("Expected MySQL session")
        }
        let values: [[String?]] = rows.map { row in
            row.map { value in
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        let batchSz = max(1, batchSize)
        let total = values.count
        totalBatches = (total + batchSz - 1) / batchSz
        let start = Date()
        let summary = try await mysql.client.importRows(
            into: tableName, schema: schema.isEmpty ? nil : schema, columns: columns, rows: values, batchSize: batchSz
        ) { [weak self] done in
            try Task.checkCancellation()
            await MainActor.run {
                guard let self else { return }
                self.completedBatches = (done + batchSz - 1) / batchSz
                self.importedRowCount = done
                self.activityHandle?.updateProgress(Double(done) / Double(max(total, 1)))
            }
        }

        timerTask?.cancel()
        completionNote = Self.completionNote(for: summary)
        importedRowCount = summary.rowCount
        completedBatches = summary.batches
        let duration = Date().timeIntervalSince(start)
        elapsedTime = duration
        phase = .completed(rowCount: summary.rowCount, duration: duration)
    }

    /// What to say after a MySQL import besides the count (round 25, ME1).
    nonisolated static func completionNote(for summary: MySQLImportSummary) -> String? {
        var notes: [String] = []
        if summary.method == .insertStatements {
            notes.append("Imported with INSERT statements: the server doesn't allow LOAD DATA LOCAL (local_infile is off).")
        }
        if let first = summary.warnings.first {
            let more = summary.warnings.count > 1 ? ", and \(summary.warnings.count - 1) more" : ""
            notes.append("The server changed some values to fit (its strict mode is off): \(first.message)\(more).")
        }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }
}

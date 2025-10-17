import Foundation
import SQLite3

@main
struct SQLiteBenchmark {
    static func main() throws {
        let totalRows = 50_000
        let batchTarget = 500
        let tracker = QueryPerformanceTracker(initialBatchTarget: batchTarget)
        tracker.markQueryDispatched()

        var db: OpaquePointer?
        guard sqlite3_open(":memory:", &db) == SQLITE_OK, let db else {
            fatalError("Failed to open in-memory SQLite database")
        }
        defer { sqlite3_close(db) }

        try exec(db, sql: "CREATE TABLE numbers (id INTEGER PRIMARY KEY, label TEXT NOT NULL);")

        var inserted = 0
        while inserted < totalRows {
            let upper = min(inserted + 10_000, totalRows)
            var values: [String] = []
            values.reserveCapacity(upper - inserted)
            for index in inserted..<upper {
                let label = String(format: "Row %06d", index + 1)
                values.append("(\(index + 1), '\(label)')")
            }
            let sql = "INSERT INTO numbers (id, label) VALUES \(values.joined(separator: ", "));"
            try exec(db, sql: sql)
            inserted = upper
        }

        let querySQL = "SELECT id, label FROM numbers ORDER BY id;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(db))
            fatalError("Failed to prepare select statement: \(message)")
        }
        defer { sqlite3_finalize(statement) }

        let start = CFAbsoluteTimeGetCurrent()

        var totalCount = 0
        var pending = 0
        var firstReloadRecorded = false
        var visibleRecorded = false

        func flushPending() {
            guard pending > 0 else { return }
            tracker.recordStreamUpdate(appendedRowCount: pending, totalRowCount: totalCount)
            if !firstReloadRecorded {
                tracker.recordTableReload()
                firstReloadRecorded = true
            }
            if !visibleRecorded, totalCount >= batchTarget {
                tracker.recordVisibleInitialLimitSatisfied()
                visibleRecorded = true
            }
            pending = 0
        }

        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_ROW {
                totalCount += 1
                pending += 1
                let threshold: Int
                switch totalCount {
                case 0..<256: threshold = 64
                case 256..<2048: threshold = 256
                default: threshold = 512
                }
                if pending >= threshold {
                    flushPending()
                }
            } else if stepResult == SQLITE_DONE {
                break
            } else {
                let message = String(cString: sqlite3_errmsg(db))
                fatalError("SQLite error during iteration: \(message)")
            }
        }

        flushPending()
        tracker.markResultSetReceived(totalRowCount: totalCount)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let report = tracker.finalize(
            cancelled: false,
            finalRowCount: totalCount,
            estimatedMemoryBytes: nil
        )

        print("SQLite streaming benchmark")
        print("-------------------------")
        print("Total rows: \(report.totalRows)")
        print(String(format: "Elapsed wall time: %.3f s", elapsed))
        if let total = report.timings.startToFinish {
            print(String(format: "Tracker total: %.3f s", total))
        }
        if let first = report.timings.dispatchToFirstUpdate ?? report.timings.startToFirstUpdate {
            print(String(format: "Time to first batch: %.3f s", first))
        }
        if let initial = report.timings.startToInitialBatch {
            print(String(format: "Time to initial \(batchTarget) rows: %.3f s", initial))
        }
        if let grid = report.timings.startToVisibleInitialLimit {
            print(String(format: "UI visible limit reached: %.3f s", grid))
        }
        if let cpu = report.cpuTotalSeconds {
            print(String(format: "Process CPU seconds: %.3f s", cpu))
        }
        if let rss = report.residentMemoryBytes {
            print("Resident memory: \(formatBytes(rss))")
        }
        if let batches = report.batchSizes.max() {
            print("Largest batch size: \(batches)")
        }
        print("Batch updates: \(report.batchCount)")
    }

    private static func exec(_ db: OpaquePointer, sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLiteBenchmark", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static func formatBytes(_ bytes: Int) -> String {
        guard bytes > 0 else { return "0 B" }
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var index = 0
        while value >= 1024.0, index < units.count - 1 {
            value /= 1024.0
            index += 1
        }
        if index == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.2f %@", value, units[index])
    }
}

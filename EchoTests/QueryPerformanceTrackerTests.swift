import XCTest
@testable import Echo

final class QueryPerformanceTrackerTests: XCTestCase {
    private struct BenchmarkResult {
        let report: QueryPerformanceTracker.Report
        let elapsed: TimeInterval
    }

    func testSQLiteBaselineProducesPerformanceReport() async throws {
        let session = try await makeInMemorySQLiteSession()
        defer { Task { await session.close() } }

        try await populateSampleData(using: session, rowCount: 50_000)

        let benchmark = try await runBenchmark(session: session, sql: """
        SELECT id, label
        FROM numbers
        ORDER BY id
        """)

        let report = benchmark.report

        XCTAssertEqual(report.totalRows, 50_000)
        XCTAssertNotNil(report.timings.startToFirstUpdate)
        XCTAssertNotNil(report.timings.startToFinish)
        XCTAssertEqual(report.batchCount > 0, true)
        XCTAssertEqual(report.timeline.last?.rows, 50_000)

        let summary = describe(report: report)
        let attachment = XCTAttachment(string: summary)
        attachment.name = "SQLite Streaming Baseline"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertLessThan(benchmark.elapsed, 5.0, "Baseline query took unexpectedly long")
    }

    // MARK: - Helpers

    private func makeInMemorySQLiteSession() async throws -> DatabaseSession {
        let factory = await MainActor.run { SQLiteFactory() }
        return try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(username: "local", password: nil)
        )
    }

    private func populateSampleData(using session: DatabaseSession, rowCount: Int) async throws {
        _ = try await session.simpleQuery("DROP TABLE IF EXISTS numbers;")
        _ = try await session.simpleQuery("CREATE TABLE numbers (id INTEGER PRIMARY KEY, label TEXT NOT NULL);")

        let batchSize = 10_000
        var inserted = 0

        while inserted < rowCount {
            let upper = min(inserted + batchSize, rowCount)
            let values = (inserted..<upper)
                .map { index in
                    let label = String(format: "Row %06d", index + 1)
                    return "(\(index + 1), '\(label)')"
                }
                .joined(separator: ", ")
            let sql = "INSERT INTO numbers (id, label) VALUES \(values);"
            _ = try await session.simpleQuery(sql)
            inserted = upper
        }
    }

    private func runBenchmark(session: DatabaseSession, sql: String) async throws -> BenchmarkResult {
        let cacheRoot = FileManager.default.temporaryDirectory.appendingPathComponent("EchoBenchmarkResultCache", isDirectory: true)
        let spoolManager = ResultSpoolManager(configuration: ResultSpoolConfiguration.defaultConfiguration(rootDirectory: cacheRoot))
        let state = await MainActor.run {
            QueryEditorState(sql: sql, initialVisibleRowBatch: 500, spoolManager: spoolManager)
        }

        await MainActor.run {
            state.startExecution()
            state.recordQueryDispatched()
        }

        let start = CFAbsoluteTimeGetCurrent()

        let result = try await session.simpleQuery(sql) { update in
            Task { @MainActor in
                state.applyStreamUpdate(update)
            }
        }

        await MainActor.run {
            state.consumeFinalResult(result)
            state.finishExecution()
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let report = await MainActor.run {
            state.lastPerformanceReport
        }

        guard let report else {
            throw XCTSkip("No performance report produced")
        }

        return BenchmarkResult(report: report, elapsed: elapsed)
    }

    private func describe(report: QueryPerformanceTracker.Report) -> String {
        var lines: [String] = []
        func format(_ label: String, _ interval: TimeInterval?) {
            guard let interval else {
                lines.append("\(label): n/a")
                return
            }
            let milliseconds = interval * 1_000
            if milliseconds >= 1_000 {
                lines.append(String(format: "%@: %.2f s", label, milliseconds / 1_000))
            } else {
                lines.append(String(format: "%@: %.0f ms", label, milliseconds))
            }
        }

        lines.append("rows: \(report.totalRows)")
        lines.append("batches: \(report.batchCount)")
        if let batch = report.firstBatchSize {
            lines.append("first batch: \(batch)")
        }
        lines.append("largest batch: \(report.largestBatchSize)")
        format("dispatch", report.timings.startToDispatch)
        format("first-row", report.timings.dispatchToFirstUpdate ?? report.timings.startToFirstUpdate)
        format("initial-\(report.initialBatchTarget)", report.timings.startToInitialBatch)
        format("result-set", report.timings.startToResultSet)
        format("grid-ready", report.timings.startToVisibleInitialLimit)
        format("total", report.timings.startToFinish)

        if let cpu = report.cpuTotalSeconds {
            lines.append(String(format: "cpu total: %.3f s", cpu))
        }
        if let rss = report.residentMemoryBytes {
            lines.append("rss: \(formatBytes(rss))")
        }
        if let est = report.estimatedMemoryBytes {
            lines.append("estimated grid memory: \(formatBytes(est))")
        }

        return lines.joined(separator: "\n")
    }

    private func formatBytes(_ bytes: Int) -> String {
        guard bytes > 0 else { return "0 B" }
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        if index == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.2f %@", value, units[index])
    }
}

import Foundation
import XCTest
@testable import Echo

/// Thread-safe boolean flag for cross-isolation use in tests.
private final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool { lock.withLock { _value } }
    func set() { lock.withLock { _value = true } }
}

/// Runs streaming benchmarks against a live Postgres database when connection
/// credentials are supplied via environment variables. Skips automatically when
/// no credentials are provided so CI/local runs stay green.
///
/// Required environment variables:
///   - ECHO_POSTGRES_HOST
///   - ECHO_POSTGRES_PORT (integer)
///   - ECHO_POSTGRES_DATABASE
///   - ECHO_POSTGRES_USERNAME
///   - ECHO_POSTGRES_PASSWORD
///
/// Optional:
///   - ECHO_POSTGRES_SSL (true/false, default false)
///   - ECHO_POSTGRES_BASE_QUERY (defaults to "SELECT * FROM public.fixture")
///       The runner appends `LIMIT {rows}` for each benchmark iteration.
///
/// Example:
///   ECHO_POSTGRES_HOST=tippr.dk \
///   ECHO_POSTGRES_PORT=5432 \
///   ECHO_POSTGRES_DATABASE=tippr \
///   ECHO_POSTGRES_USERNAME=rundeckuser \
///   ECHO_POSTGRES_PASSWORD=secret \
///   ECHO_POSTGRES_BASE_QUERY="SELECT * FROM public.fixture" \
///   xcodebuild test -scheme Echo -destination 'platform=macOS' \
///       -only-testing:EchoTests/PostgresStreamingBenchmarkTests/testPostgresStreamingBenchmarks
@MainActor
final class PostgresStreamingBenchmarkTests: XCTestCase {
    private struct ConnectionConfig {
        let host: String
        let port: Int
        let database: String
        let username: String
        let password: String
        let useTLS: Bool
        let baseQuery: String
    }

    private struct BenchmarkResult {
        let label: String
        let rowCount: Int
        let report: QueryPerformanceTracker.Report
        let elapsed: TimeInterval
    }

    func testPostgresStreamingBenchmarks() async throws {
        guard let config = loadConfigurationFromEnvironment() else {
            print("[PostgresBenchmark] skipping: missing configuration")
            throw XCTSkip("Postgres credentials not configured (set ECHO_POSTGRES_* environment variables).")
        }
        let factory = await MainActor.run { PostgresNIOFactory() }

        UserDefaults.standard.set(4_096, forKey: ResultStreamingFetchSizeDefaultsKey)
        UserDefaults.standard.set(24, forKey: ResultStreamingFetchRampMultiplierDefaultsKey)
        UserDefaults.standard.set(524_288, forKey: ResultStreamingFetchRampMaxDefaultsKey)

        let authentication = DatabaseAuthenticationConfiguration(
            method: .sqlPassword,
            username: config.username,
            password: config.password
        )

        let session = try await factory.connect(
            host: config.host,
            port: config.port,
            database: config.database,
            tls: config.useTLS,
            authentication: authentication
        )
        defer { Task { await session.close() } }

        let benchmarks: [(label: String, rows: Int)] = [
            ("limit_100", 100),
            ("limit_1000", 1_000),
            ("limit_10000", 10_000),
            ("limit_100000", 100_000)
        ]

        var results: [BenchmarkResult] = []
        results.reserveCapacity(benchmarks.count)

        for benchmark in benchmarks {
            let sql = makeQuery(base: config.baseQuery, limit: benchmark.rows)
            let result = try await runBenchmark(
                session: session,
                sql: sql,
                expectedRows: benchmark.rows,
                label: benchmark.label
            )
            results.append(result)

            let formatted = format(result: result)
            print("[PostgresBenchmark] \(benchmark.label)\n\(formatted)\n")

            let attachment = XCTAttachment(string: formatted)
            attachment.name = "Postgres \(benchmark.label)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        // Aggregate summary for quick inspection.
        let summaryLines = results.map { result in
            String(format: "%@ -> rows=%d elapsed=%.3fs batches=%d largest=%d",
                   result.label,
                   result.rowCount,
                   result.elapsed,
                   result.report.batchCount,
                   result.report.largestBatchSize)
        }
        let summaryAttachment = XCTAttachment(string: summaryLines.joined(separator: "\n"))
        summaryAttachment.name = "Postgres Benchmark Summary"
        summaryAttachment.lifetime = .keepAlways
        add(summaryAttachment)
        print("[PostgresBenchmark] summary\n\(summaryLines.joined(separator: "\n"))\n")
    }

    // MARK: - Helpers

    private func makeQuery(base: String, limit: Int) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutSemicolon: String
        if trimmed.hasSuffix(";") {
            withoutSemicolon = String(trimmed.dropLast())
        } else {
            withoutSemicolon = trimmed
        }
        return "\(withoutSemicolon) LIMIT \(limit);"
    }

    private func runBenchmark(
        session: DatabaseSession,
        sql: String,
        expectedRows: Int,
        label: String
    ) async throws -> BenchmarkResult {
        let initialBatchTarget = 500
        let tracker = QueryPerformanceTracker(initialBatchTarget: initialBatchTarget)
        tracker.markQueryDispatched()
        let initialBatchFlag = AtomicFlag()

        let start = CFAbsoluteTimeGetCurrent()

        let result = try await session.simpleQuery(sql) { update in
            Task { @MainActor in
                tracker.recordStreamUpdate(
                    appendedRowCount: update.appendedRows.count,
                    totalRowCount: update.totalRowCount
                )
                if let metrics = update.metrics {
                    tracker.recordBackendMetrics(metrics)
                }
                if !initialBatchFlag.value, update.totalRowCount >= initialBatchTarget {
                    tracker.recordInitialBatchReady(totalRowCount: update.totalRowCount)
                    tracker.recordVisibleInitialLimitSatisfied()
                    tracker.recordTableReload()
                    initialBatchFlag.set()
                }
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let resolvedRowCount = result.totalRowCount ?? result.rows.count
        XCTAssertEqual(resolvedRowCount, expectedRows, "Unexpected row count for \(label)")
        tracker.markResultSetReceived(totalRowCount: resolvedRowCount)
        let report = tracker.finalize(cancelled: false, finalRowCount: resolvedRowCount, estimatedMemoryBytes: nil)
        return BenchmarkResult(label: label, rowCount: resolvedRowCount, report: report, elapsed: elapsed)
    }

    private func format(result: BenchmarkResult) -> String {
        var lines: [String] = []
        lines.append("label: \(result.label)")
        lines.append("rows: \(result.report.totalRows)")
        lines.append(String(format: "elapsed: %.3f s", result.elapsed))
        lines.append("batches: \(result.report.batchCount)")
        lines.append("largest batch: \(result.report.largestBatchSize)")

        func formatInterval(_ name: String, _ interval: TimeInterval?) {
            guard let interval else {
                lines.append("\(name): n/a")
                return
            }
            lines.append(String(format: "%@: %.3f s", name, interval))
        }

        let timings = result.report.timings
        formatInterval("dispatch", timings.startToDispatch)
        formatInterval("first-update", timings.dispatchToFirstUpdate ?? timings.startToFirstUpdate)
        formatInterval("initial-batch", timings.startToInitialBatch)
        formatInterval("grid-ready", timings.startToVisibleInitialLimit)
        formatInterval("total", timings.startToFinish)

        if let cpu = result.report.cpuTotalSeconds {
            lines.append(String(format: "cpu: %.3f s", cpu))
        }
        if let rss = result.report.residentMemoryBytes {
            lines.append("rss: \(formatBytes(rss))")
        }
        if let est = result.report.estimatedMemoryBytes {
            lines.append("estimated grid memory: \(formatBytes(est))")
        }

        if !result.report.backendSamples.isEmpty {
            let waits = result.report.backendSamples.map { $0.networkWaitDuration }
            let avgWait = waits.reduce(0, +) / Double(waits.count)
            let maxWait = waits.max() ?? 0
            let requestSizes = Set(result.report.backendSamples.compactMap { $0.fetchRequestRowCount })
            let actualSizes = result.report.backendSamples.compactMap { $0.fetchRowCount }
            let avgFetch = actualSizes.isEmpty ? 0 : Double(actualSizes.reduce(0, +)) / Double(actualSizes.count)
            if !requestSizes.isEmpty {
                let sortedRequests = requestSizes.sorted()
                let requestSummary = sortedRequests.map { "\($0)" }.joined(separator: ",")
                lines.append(String(format: "fetch-req sizes: %@", requestSummary))
            }
            if !actualSizes.isEmpty {
                let actualSummary = actualSizes.map { "\($0)" }.joined(separator: ",")
                lines.append("fetch-rows counts: \(actualSummary)")
            }
            if avgFetch > 0 {
                lines.append(String(format: "fetch-rows avg: %.1f", avgFetch))
            }
            lines.append(String(format: "wait avg/max: %.3f/%.3f s", avgWait, maxWait))
        }

        return lines.joined(separator: "\n")
    }

    private func loadConfigurationFromEnvironment() -> ConnectionConfig? {
        var env = ProcessInfo.processInfo.environment
        if let config = makeConfiguration(from: env) {
            return config
        }

        if let envFile = (env["POSTGRES_BENCHMARK_ENV_FILE"]?.nonEmpty) ?? defaultBenchmarkEnvFile(),
           let fileVars = parseEnvFile(at: envFile) {
            for (key, value) in fileVars where env[key] == nil {
                env[key] = value
            }
            if let config = makeConfiguration(from: env) {
                return config
            }
        }

        return nil
    }

    private func makeConfiguration(from env: [String: String]) -> ConnectionConfig? {
        guard
            let host = env["ECHO_POSTGRES_HOST"],
            let portString = env["ECHO_POSTGRES_PORT"], let port = Int(portString),
            let database = env["ECHO_POSTGRES_DATABASE"],
            let username = env["ECHO_POSTGRES_USERNAME"],
            let password = env["ECHO_POSTGRES_PASSWORD"]
        else {
            return nil
        }

        let useTLS = env["ECHO_POSTGRES_SSL"]?.lowercased() == "true"
        let baseQuery = env["ECHO_POSTGRES_BASE_QUERY"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "SELECT * FROM public.fixture"

        return ConnectionConfig(
            host: host,
            port: port,
            database: database,
            username: username,
            password: password,
            useTLS: useTLS,
            baseQuery: baseQuery
        )
    }

    private func parseEnvFile(at path: String) -> [String: String]? {
        guard let contents = try? String(contentsOfFile: path) else {
            return nil
        }
        var result: [String: String] = [:]
        let lines = contents.split(whereSeparator: \.isNewline)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }

    private func defaultBenchmarkEnvFile() -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PostgresStreamingBenchmarkTests.swift
            .deletingLastPathComponent() // EchoTests
        let candidate = root.appendingPathComponent(".env").path
        return FileManager.default.fileExists(atPath: candidate) ? candidate : nil
    }

    private func formatBytes(_ bytes: Int) -> String {
        guard bytes > 0 else { return "0 B" }
        let units: [String] = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024.0, unitIndex < units.count - 1 {
            value /= 1024.0
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.2f %@", value, units[unitIndex])
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

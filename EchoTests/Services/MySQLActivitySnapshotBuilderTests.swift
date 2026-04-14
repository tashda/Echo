import Foundation
import Testing
import MySQLKit
@testable import Echo

struct MySQLActivitySnapshotBuilderTests {
    @Test func buildsOverviewAndRatesFromStatusDeltas() {
        let previous = MySQLActivityStatusSample(
            capturedAt: Date(timeIntervalSinceReferenceDate: 100),
            variables: [
                "bytes_received": "1000",
                "bytes_sent": "2000",
                "questions": "50",
                "innodb_data_reads": "25",
                "innodb_data_writes": "10"
            ]
        )

        let result = MySQLActivitySnapshotBuilder.makeSnapshot(
            capturedAt: Date(timeIntervalSinceReferenceDate: 105),
            processes: [
                MySQLProcess(
                    id: 17,
                    user: "app",
                    host: "localhost",
                    database: "sakila",
                    command: "Query",
                    timeSeconds: 2,
                    state: "executing",
                    info: "SELECT 1"
                )
            ],
            statusVariables: [
                .init(name: "Uptime", value: "3600"),
                .init(name: "Threads_connected", value: "4"),
                .init(name: "Bytes_received", value: "2024"),
                .init(name: "Bytes_sent", value: "4048"),
                .init(name: "Questions", value: "90"),
                .init(name: "Slow_queries", value: "3"),
                .init(name: "Open_tables", value: "21"),
                .init(name: "Innodb_buffer_pool_pages_data", value: "75"),
                .init(name: "Innodb_buffer_pool_pages_total", value: "100"),
                .init(name: "Innodb_data_reads", value: "35"),
                .init(name: "Innodb_data_writes", value: "25")
            ],
            globalVariables: [
                .init(name: "max_connections", value: "100"),
                .init(name: "table_open_cache", value: "64")
            ],
            previousSample: previous
        )

        let overview = try! #require(result.snapshot.overview)
        #expect(overview.currentConnections == 4)
        #expect(overview.maxConnections == 100)
        #expect(overview.uptimeSeconds == 3600)
        #expect(overview.slowQueries == 3)
        #expect(overview.tableOpenCache == 64)
        #expect(overview.bufferPoolUsagePercent == 75)
        #expect(overview.bytesReceivedPerSecond == 204.8)
        #expect(overview.bytesSentPerSecond == 409.6)
        #expect(overview.queriesPerSecond == 8)
        #expect(overview.innodbReadsPerSecond == 2)
        #expect(overview.innodbWritesPerSecond == 3)
        #expect(result.snapshot.processes.first?.id == 17)
        #expect(result.snapshot.globalVariables.first(where: { $0.name == "max_connections" })?.category == "MAX")
    }

    @Test func fallsBackToProcessCountWithoutThreadMetric() {
        let result = MySQLActivitySnapshotBuilder.makeSnapshot(
            capturedAt: Date(),
            processes: [
                MySQLProcess(
                    id: 1,
                    user: "root",
                    host: nil,
                    database: nil,
                    command: "Sleep",
                    timeSeconds: 10,
                    state: nil,
                    info: nil
                ),
                MySQLProcess(
                    id: 2,
                    user: "app",
                    host: nil,
                    database: "inventory",
                    command: "Query",
                    timeSeconds: 1,
                    state: nil,
                    info: "SELECT * FROM products"
                )
            ],
            statusVariables: [],
            globalVariables: [],
            previousSample: nil
        )

        let overview = try! #require(result.snapshot.overview)
        #expect(overview.currentConnections == 2)
        #expect(overview.queriesPerSecond == nil)
        #expect(overview.bytesReceivedPerSecond == nil)
    }
}

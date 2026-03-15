import Testing
import Foundation
@testable import Echo

@Suite("ResultSpoolConfiguration")
struct ResultSpoolConfigurationTests {

    // MARK: - Default Configuration

    @Test func defaultConfigurationValues() {
        let rootDir = URL(fileURLWithPath: "/tmp/spool")
        let config = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: rootDir)

        #expect(config.rootDirectory == rootDir)
        #expect(config.maximumBytes == 5 * 1_024 * 1_024 * 1_024)
        #expect(config.retentionInterval == 72 * 60 * 60)
        #expect(config.inMemoryRowLimit == 500)
    }

    @Test func defaultConfigurationMaximumBytesIs5GB() {
        let config = ResultSpoolConfiguration.defaultConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp")
        )
        #expect(config.maximumBytes == 5_368_709_120) // 5 GB exact
    }

    @Test func defaultConfigurationRetentionIs72Hours() {
        let config = ResultSpoolConfiguration.defaultConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp")
        )
        #expect(config.retentionInterval == 259_200) // 72 * 3600
    }

    // MARK: - Equatable Conformance

    @Test func equalConfigurationsAreEqual() {
        let a = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp/a"),
            maximumBytes: 1000,
            retentionInterval: 3600,
            inMemoryRowLimit: 100
        )
        let b = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp/a"),
            maximumBytes: 1000,
            retentionInterval: 3600,
            inMemoryRowLimit: 100
        )
        #expect(a == b)
    }

    @Test func differentRootDirectoriesAreNotEqual() {
        let a = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp/a"),
            maximumBytes: 1000,
            retentionInterval: 3600,
            inMemoryRowLimit: 100
        )
        let b = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp/b"),
            maximumBytes: 1000,
            retentionInterval: 3600,
            inMemoryRowLimit: 100
        )
        #expect(a != b)
    }

    @Test func differentMaximumBytesAreNotEqual() {
        let a = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp"),
            maximumBytes: 1000,
            retentionInterval: 3600,
            inMemoryRowLimit: 100
        )
        let b = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp"),
            maximumBytes: 2000,
            retentionInterval: 3600,
            inMemoryRowLimit: 100
        )
        #expect(a != b)
    }

    @Test func differentRetentionIntervalsAreNotEqual() {
        let a = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp"),
            maximumBytes: 1000,
            retentionInterval: 3600,
            inMemoryRowLimit: 100
        )
        let b = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp"),
            maximumBytes: 1000,
            retentionInterval: 7200,
            inMemoryRowLimit: 100
        )
        #expect(a != b)
    }

    @Test func differentInMemoryRowLimitsAreNotEqual() {
        let a = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp"),
            maximumBytes: 1000,
            retentionInterval: 3600,
            inMemoryRowLimit: 100
        )
        let b = ResultSpoolConfiguration(
            rootDirectory: URL(fileURLWithPath: "/tmp"),
            maximumBytes: 1000,
            retentionInterval: 3600,
            inMemoryRowLimit: 200
        )
        #expect(a != b)
    }

    // MARK: - ResultSpoolStats Codable

    @Test func resultSpoolStatsCodableRoundTrip() throws {
        let metrics = QueryStreamMetrics(
            batchRowCount: 100,
            loopElapsed: 0.5,
            decodeDuration: 0.1,
            totalElapsed: 1.0,
            cumulativeRowCount: 500
        )
        let stats = ResultSpoolStats(
            spoolID: UUID(),
            rowCount: 1000,
            lastBatchCount: 50,
            cumulativeBytes: 1_024_000,
            lastUpdated: Date(),
            metrics: metrics,
            isFinished: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(stats)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ResultSpoolStats.self, from: data)

        #expect(decoded.spoolID == stats.spoolID)
        #expect(decoded.rowCount == stats.rowCount)
        #expect(decoded.lastBatchCount == stats.lastBatchCount)
        #expect(decoded.cumulativeBytes == stats.cumulativeBytes)
        #expect(decoded.isFinished == stats.isFinished)
        #expect(decoded.metrics?.batchRowCount == 100)
        #expect(decoded.metrics?.cumulativeRowCount == 500)
    }

    @Test func resultSpoolStatsWithNilMetrics() throws {
        let stats = ResultSpoolStats(
            spoolID: UUID(),
            rowCount: 0,
            lastBatchCount: 0,
            cumulativeBytes: 0,
            lastUpdated: Date(),
            metrics: nil,
            isFinished: false
        )

        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(ResultSpoolStats.self, from: data)

        #expect(decoded.metrics == nil)
        #expect(decoded.rowCount == 0)
        #expect(decoded.isFinished == false)
    }

    // MARK: - ResultSpoolMetadata Codable

    @Test func resultSpoolMetadataCodableRoundTrip() throws {
        let columns = [
            ColumnInfo(name: "id", dataType: "int4", isPrimaryKey: true, isNullable: false),
            ColumnInfo(name: "name", dataType: "text", isPrimaryKey: false, isNullable: true)
        ]
        let metrics = QueryStreamMetrics(
            batchRowCount: 50,
            loopElapsed: 0.3,
            decodeDuration: 0.05,
            totalElapsed: 0.8,
            cumulativeRowCount: 200
        )
        let metadata = ResultSpoolMetadata(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            totalRowCount: 500,
            commandTag: "SELECT 500",
            isFinished: true,
            columns: columns,
            cumulativeBytes: 50_000,
            latestMetrics: metrics,
            rowEncoding: "binary-v1"
        )

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(ResultSpoolMetadata.self, from: data)

        #expect(decoded.id == metadata.id)
        #expect(decoded.totalRowCount == 500)
        #expect(decoded.commandTag == "SELECT 500")
        #expect(decoded.isFinished == true)
        #expect(decoded.columns.count == 2)
        #expect(decoded.columns[0].name == "id")
        #expect(decoded.columns[0].isPrimaryKey == true)
        #expect(decoded.columns[1].name == "name")
        #expect(decoded.columns[1].isNullable == true)
        #expect(decoded.cumulativeBytes == 50_000)
        #expect(decoded.latestMetrics?.batchRowCount == 50)
        #expect(decoded.rowEncoding == "binary-v1")
    }

    @Test func resultSpoolMetadataWithNilOptionals() throws {
        let metadata = ResultSpoolMetadata(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            totalRowCount: 0,
            commandTag: nil,
            isFinished: false,
            columns: [],
            cumulativeBytes: 0,
            latestMetrics: nil,
            rowEncoding: nil
        )

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(ResultSpoolMetadata.self, from: data)

        #expect(decoded.commandTag == nil)
        #expect(decoded.latestMetrics == nil)
        #expect(decoded.rowEncoding == nil)
        #expect(decoded.columns.isEmpty)
    }

    // MARK: - ResultSpoolError

    @Test func resultSpoolErrorCasesExist() {
        let errors: [ResultSpoolError] = [
            .headerAlreadyWritten,
            .headerMissing,
            .fileClosed,
            .invalidRange
        ]
        #expect(errors.count == 4)
    }

    @Test func resultSpoolErrorIsError() {
        let error: Error = ResultSpoolError.headerMissing
        #expect(error is ResultSpoolError)
    }

    @Test func resultSpoolErrorCasesAreDistinct() {
        let a = ResultSpoolError.headerAlreadyWritten
        let b = ResultSpoolError.headerMissing
        let c = ResultSpoolError.fileClosed
        let d = ResultSpoolError.invalidRange

        // Use string descriptions to verify distinctness
        let descriptions = [a, b, c, d].map { "\($0)" }
        let uniqueDescriptions = Set(descriptions)
        #expect(uniqueDescriptions.count == 4)
    }

    // MARK: - ResultBinaryRow

    @Test func resultBinaryRowDataStorageRoundTrip() {
        let testData = Data([0x01, 0x02, 0x03])
        let row = ResultBinaryRow(data: testData)

        if case .data(let stored) = row.storage {
            #expect(stored == testData)
        } else {
            Issue.record("Expected .data storage")
        }
    }

    @Test func resultBinaryRowDataPropertyReturnsCorrectData() {
        let testData = Data([0x00, 0x01, 0x05, 0x00, 0x00, 0x00])
        let row = ResultBinaryRow(data: testData)
        #expect(row.data == testData)
    }

    @Test func resultBinaryRowIsSendable() {
        // This is a compile-time check — if ResultBinaryRow is not Sendable, this won't compile
        let row = ResultBinaryRowCodec.encode(row: ["test"])
        let sendableRow: any Sendable = row
        #expect(sendableRow is ResultBinaryRow)
    }
}

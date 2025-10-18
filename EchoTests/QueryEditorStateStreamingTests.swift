import XCTest
@testable import Echo

@MainActor
final class QueryEditorStateStreamingTests: XCTestCase {
    func testMetricsOnlyUpdatesDoNotAdvanceRowCount() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("QueryEditorStateStreamingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let spoolConfig = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        let spoolManager = ResultSpoolManager(configuration: spoolConfig)

        let state = QueryEditorState(
            sql: "SELECT 1;",
            initialVisibleRowBatch: 500,
            previewRowLimit: 512,
            spoolManager: spoolManager
        )
        state.startExecution()

        let columns = [ColumnInfo(name: "id", dataType: "int4")]
        let previewRows = (0..<512).map { ["\($0)"] }
        let previewMetrics = QueryStreamMetrics(
            batchRowCount: 512,
            loopElapsed: 0.01,
            decodeDuration: 0,
            totalElapsed: 0.01,
            cumulativeRowCount: 512
        )

        let previewUpdate = QueryStreamUpdate(
            columns: columns,
            appendedRows: previewRows,
            encodedRows: [],
            totalRowCount: 512,
            metrics: previewMetrics,
            rowRange: 0..<512
        )
        state.applyStreamUpdate(previewUpdate)
        XCTAssertEqual(state.totalAvailableRowCount, 512)

        let metricsOnlyUpdate = QueryStreamUpdate(
            columns: columns,
            appendedRows: [],
            encodedRows: [],
            totalRowCount: 512,
            metrics: previewMetrics,
            rowRange: nil
        )
        state.applyStreamUpdate(metricsOnlyUpdate)
        XCTAssertEqual(state.totalAvailableRowCount, 512)

        state.finishExecution()
    }
}

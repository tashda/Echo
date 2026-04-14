import XCTest
@testable import Echo

@MainActor
final class QueryEditorStateMultiResultTests: XCTestCase {
    private var spoolManager: ResultSpooler!
    private var retainedStates: [QueryEditorState] = []

    override func setUp() async throws {
        try await super.setUp()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MultiResultTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let config = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        spoolManager = ResultSpooler(configuration: config)
        retainedStates = []
    }

    override func tearDown() async throws {
        retainedStates.removeAll()
        spoolManager = nil
        try await super.tearDown()
    }

    private func makeState(sql: String = "SELECT 1") -> QueryEditorState {
        let state = QueryEditorState(
            sql: sql,
            initialVisibleRowBatch: 500,
            previewRowLimit: 512,
            spoolManager: spoolManager,
            backgroundFetchSize: 4_096
        )
        retainedStates.append(state)
        return state
    }

    // MARK: - Multi-Result-Set Tests

    func testConsumeResultWithAdditionalResults() async {
        let state = makeState()
        state.startExecution()

        let secondary = QueryResultSet(
            columns: [ColumnInfo(name: "count", dataType: "int")],
            rows: [["42"]],
            totalRowCount: 1
        )
        let primary = QueryResultSet(
            columns: [ColumnInfo(name: "id", dataType: "int"), ColumnInfo(name: "name", dataType: "text")],
            rows: [["1", "Alice"], ["2", "Bob"]],
            totalRowCount: 2,
            additionalResults: [secondary]
        )

        state.consumeFinalResult(primary)

        XCTAssertEqual(state.additionalResults.count, 1, "Should have 1 additional result set")
        XCTAssertEqual(state.selectedResultSetIndex, 0, "Should default to first result set")
        XCTAssertEqual(state.additionalResults.first?.columns.first?.name, "count")
    }

    func testStartExecutionClearsAdditionalResults() async {
        let state = makeState()
        state.startExecution()

        let secondary = QueryResultSet(
            columns: [ColumnInfo(name: "extra", dataType: "text")],
            rows: [["data"]],
            totalRowCount: 1
        )
        let primary = QueryResultSet(
            columns: [ColumnInfo(name: "id", dataType: "int")],
            rows: [["1"]],
            totalRowCount: 1,
            additionalResults: [secondary]
        )
        state.consumeFinalResult(primary)
        state.finishExecution()

        XCTAssertEqual(state.additionalResults.count, 1)

        // Start new execution — should clear additional results
        state.startExecution()
        XCTAssertTrue(state.additionalResults.isEmpty, "Additional results should be cleared on new execution")
        XCTAssertEqual(state.selectedResultSetIndex, 0, "Selected index should reset to 0")
    }

    func testAllResultSetsForDisplay() async {
        let state = makeState()
        state.startExecution()

        let second = QueryResultSet(
            columns: [ColumnInfo(name: "b", dataType: "int")],
            rows: [["2"]],
            totalRowCount: 1
        )
        let third = QueryResultSet(
            columns: [ColumnInfo(name: "c", dataType: "int")],
            rows: [["3"]],
            totalRowCount: 1
        )
        let primary = QueryResultSet(
            columns: [ColumnInfo(name: "a", dataType: "int")],
            rows: [["1"]],
            totalRowCount: 1,
            additionalResults: [second, third]
        )
        state.consumeFinalResult(primary)

        let allSets = state.allResultSetsForDisplay
        XCTAssertEqual(allSets.count, 3, "Should have 3 result sets (primary + 2 additional)")
        XCTAssertEqual(allSets[0].columns.first?.name, "a")
        XCTAssertEqual(allSets[1].columns.first?.name, "b")
        XCTAssertEqual(allSets[2].columns.first?.name, "c")
    }

    func testSelectedResultSetIndexBounds() async {
        let state = makeState()
        state.startExecution()

        let secondary = QueryResultSet(
            columns: [ColumnInfo(name: "extra", dataType: "int")],
            rows: [["99"]],
            totalRowCount: 1
        )
        let primary = QueryResultSet(
            columns: [ColumnInfo(name: "id", dataType: "int")],
            rows: [["1"]],
            totalRowCount: 1,
            additionalResults: [secondary]
        )
        state.consumeFinalResult(primary)

        // Valid index
        state.selectedResultSetIndex = 1
        XCTAssertEqual(state.selectedResultSetIndex, 1)

        // Out of bounds — verify it can be set (views handle bounds checking)
        state.selectedResultSetIndex = 5
        XCTAssertEqual(state.selectedResultSetIndex, 5)
    }

    func testAllResultSetsForDisplayDuringStreaming() async {
        let state = makeState()
        state.startExecution()

        // Simulate streaming: set columns and rows without consuming final result
        let update = QueryStreamUpdate(
            columns: [ColumnInfo(name: "streaming_col", dataType: "int")],
            appendedRows: [["1"], ["2"], ["3"]],
            encodedRows: [],
            totalRowCount: 3,
            metrics: nil,
            rowRange: 0..<3
        )
        state.applyStreamUpdate(update)

        let allSets = state.allResultSetsForDisplay
        XCTAssertEqual(allSets.count, 1, "During streaming, should have 1 in-progress result set")
        XCTAssertEqual(allSets.first?.columns.first?.name, "streaming_col")
    }
}

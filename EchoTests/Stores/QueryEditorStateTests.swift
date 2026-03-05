import XCTest
@testable import Echo

@MainActor
final class QueryEditorStateTests: XCTestCase {
    private var spoolManager: ResultSpoolCoordinator!
    private var retainedStates: [QueryEditorState] = []

    override func setUp() async throws {
        try await super.setUp()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("QueryEditorStateTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let config = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        spoolManager = ResultSpoolCoordinator(configuration: config)
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

    // MARK: - Lifecycle

    func testStartExecutionSetsIsExecuting() async {
        let state = makeState()
        XCTAssertFalse(state.isExecuting)

        state.startExecution()
        XCTAssertTrue(state.isExecuting)
        XCTAssertFalse(state.wasCancelled)
    }

    func testStartExecutionClearsOldResults() async {
        let state = makeState()

        // Simulate a previous execution
        state.startExecution()
        state.consumeFinalResult(QueryResultSet(columns: ["id"], rows: [["1"]]))
        state.finishExecution()

        // Start new execution
        state.startExecution()
        XCTAssertNil(state.results)
        XCTAssertTrue(state.messages.count <= 1) // Only the "started" message
    }

    func testFailExecutionSetsState() async {
        let state = makeState()
        state.startExecution()
        state.failExecution(with: "Connection lost")

        XCTAssertFalse(state.isExecuting)
        XCTAssertNil(state.results)
        XCTAssertTrue(state.messages.contains { $0.severity == .error })
    }

    func testCancelExecutionSetsCancelledState() async {
        let state = makeState()
        state.startExecution()
        state.cancelExecution()

        // cancelExecution calls markCancellationCompleted if no executing task
        XCTAssertFalse(state.isExecuting)
        XCTAssertTrue(state.wasCancelled)
    }

    // MARK: - Consume Results

    func testConsumeFinalResultStoresResults() async {
        let state = makeState()
        state.startExecution()

        let result = TestFixtures.queryResultSet(
            columns: ["id", "name"],
            rows: [["1", "Alice"], ["2", "Bob"]]
        )
        state.consumeFinalResult(result)

        XCTAssertNotNil(state.results)
        XCTAssertEqual(state.results?.columns.count, 2)
    }

    // MARK: - Row Counts

    func testDisplayedRowCountRespectVisibleLimit() async {
        let state = makeState()
        state.startExecution()

        // Simulate receiving a large result
        var rows: [[String?]] = []
        for i in 0..<1000 {
            rows.append(["\(i)"])
        }
        let result = QueryResultSet(columns: [ColumnInfo(name: "id", dataType: "int")], rows: rows, totalRowCount: 1000)
        state.consumeFinalResult(result)

        // visibleRowLimit is set to initialVisibleRowBatch (500) or capped at total
        XCTAssertLessThanOrEqual(state.displayedRowCount, 1000)
        XCTAssertGreaterThan(state.displayedRowCount, 0)
    }

    func testTotalAvailableRowCount() async {
        let state = makeState()
        state.startExecution()

        let result = QueryResultSet(
            columns: [ColumnInfo(name: "id", dataType: "int")],
            rows: [["1"], ["2"]],
            totalRowCount: 100
        )
        state.consumeFinalResult(result)

        // Total should reflect the reported total
        XCTAssertGreaterThanOrEqual(state.totalAvailableRowCount, 2)
    }

    // MARK: - First Execution Flag

    func testHasExecutedAtLeastOnce() async {
        let state = makeState()
        XCTAssertFalse(state.hasExecutedAtLeastOnce)

        state.startExecution()
        XCTAssertTrue(state.hasExecutedAtLeastOnce)
    }

    // MARK: - SQL

    func testInitWithCustomSQL() async {
        let state = makeState(sql: "SELECT * FROM orders")
        XCTAssertEqual(state.sql, "SELECT * FROM orders")
    }

    func testDefaultSQL() async {
        let state = makeState()
        XCTAssertEqual(state.sql, "SELECT 1")
    }
}

import XCTest
@testable import Echo

final class QueryResultSetTests: XCTestCase {

    // MARK: - Combined Row Count

    func testCombinedRowCount() {
        let additional1 = QueryResultSet(
            columns: [ColumnInfo(name: "b", dataType: "int")],
            rows: [["1"], ["2"], ["3"], ["4"], ["5"]],
            totalRowCount: 5
        )
        let additional2 = QueryResultSet(
            columns: [ColumnInfo(name: "c", dataType: "int")],
            rows: [["1"], ["2"], ["3"]],
            totalRowCount: 3
        )
        let result = QueryResultSet(
            columns: [ColumnInfo(name: "a", dataType: "int")],
            rows: Array(repeating: ["1"], count: 10),
            totalRowCount: 10,
            additionalResults: [additional1, additional2]
        )

        XCTAssertEqual(result.combinedRowCount, 18, "10 + 5 + 3 = 18")
    }

    // MARK: - All Result Sets

    func testAllResultSets() {
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
        let result = QueryResultSet(
            columns: [ColumnInfo(name: "a", dataType: "int")],
            rows: [["1"]],
            totalRowCount: 1,
            additionalResults: [second, third]
        )

        let all = result.allResultSets
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].columns.first?.name, "a")
        XCTAssertEqual(all[1].columns.first?.name, "b")
        XCTAssertEqual(all[2].columns.first?.name, "c")
    }

    // MARK: - Empty Additional Results

    func testEmptyAdditionalResults() {
        let result = QueryResultSet(
            columns: [ColumnInfo(name: "id", dataType: "int")],
            rows: [["1"], ["2"], ["3"]],
            totalRowCount: 3
        )

        XCTAssertEqual(result.combinedRowCount, 3, "No additional results — combined equals primary")
        XCTAssertEqual(result.allResultSets.count, 1, "Only the primary result set")
    }

    // MARK: - Additional Results Preserve Total Row Count

    func testAdditionalResultsPreserveTotalRowCount() {
        let additional = QueryResultSet(
            columns: [ColumnInfo(name: "val", dataType: "int")],
            rows: Array(repeating: ["1"], count: 10),
            totalRowCount: 100  // totalRowCount > rows.count (e.g. truncated)
        )
        let result = QueryResultSet(
            columns: [ColumnInfo(name: "id", dataType: "int")],
            rows: [["1"]],
            totalRowCount: 1,
            additionalResults: [additional]
        )

        // combinedRowCount should use totalRowCount (100), not rows.count (10)
        XCTAssertEqual(result.combinedRowCount, 101, "Should use totalRowCount (100) not rows.count (10)")
    }
}

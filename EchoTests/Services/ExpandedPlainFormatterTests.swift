import Testing
@testable import Echo

@Suite("ExpandedPlainFormatter")
struct ExpandedPlainFormatterTests {

    @Test func formatSingleRecord() {
        let result = ExpandedPlainFormatter.format(
            columns: ["id", "name"],
            rows: [["1", "Alice"]]
        )
        #expect(result.contains("-[ RECORD 1 ]-"))
        #expect(result.contains("id | 1"))
        #expect(result.contains("name | Alice"))
        #expect(result.contains("(1 row)"))
    }

    @Test func formatMultipleRecords() {
        let result = ExpandedPlainFormatter.format(
            columns: ["id"],
            rows: [["1"], ["2"], ["3"]]
        )
        #expect(result.contains("-[ RECORD 1 ]-"))
        #expect(result.contains("-[ RECORD 2 ]-"))
        #expect(result.contains("-[ RECORD 3 ]-"))
        #expect(result.contains("(3 rows)"))
    }

    @Test func formatNullValues() {
        let result = ExpandedPlainFormatter.format(
            columns: ["val"],
            rows: [[nil]],
            nullDisplay: "NULL"
        )
        #expect(result.contains("val | NULL"))
    }

    @Test func formatEmptyNullDisplay() {
        let result = ExpandedPlainFormatter.format(
            columns: ["val"],
            rows: [[nil]]
        )
        #expect(result.contains("val | "))
    }

    @Test func formatEmptyColumns() {
        let result = ExpandedPlainFormatter.format(
            columns: [],
            rows: [["1"]]
        )
        #expect(result.isEmpty)
    }

    @Test func formatEmptyRows() {
        let result = ExpandedPlainFormatter.format(
            columns: ["id"],
            rows: []
        )
        #expect(result.contains("(0 rows)"))
    }

    @Test func formatRowShorterThanColumns() {
        let result = ExpandedPlainFormatter.format(
            columns: ["a", "b", "c"],
            rows: [["1"]]
        )
        // Missing columns should use null display (empty by default)
        #expect(result.contains("a | 1"))
        #expect(result.contains("b | "))
        #expect(result.contains("c | "))
    }
}

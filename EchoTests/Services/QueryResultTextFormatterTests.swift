import Testing
@testable import Echo

@Suite("QueryResultTextFormatter")
struct QueryResultTextFormatterTests {
    @Test func tableFormatProducesAlignedGrid() {
        let resultSet = QueryResultSet(
            columns: [
                ColumnInfo(name: "id", dataType: "int"),
                ColumnInfo(name: "name", dataType: "text"),
            ],
            rows: [
                ["1", "Alice"],
                ["20", nil],
            ]
        )

        let formatted = QueryResultTextFormatter.formatTable(resultSet: resultSet)

        #expect(formatted.contains("id | name "))
        #expect(formatted.contains("--+"))
        #expect(formatted.contains("20 | NULL "))
        #expect(formatted.contains("(2 rows)"))
    }

    @Test func tableFormatEscapesEmbeddedNewlines() {
        let resultSet = QueryResultSet(
            columns: [ColumnInfo(name: "note", dataType: "text")],
            rows: [["line1\nline2"]]
        )

        let formatted = QueryResultTextFormatter.formatTable(resultSet: resultSet)

        #expect(formatted.contains("line1\\nline2"))
    }

    @Test func verticalFormatProducesRecordStyleOutput() {
        let resultSet = QueryResultSet(
            columns: [
                ColumnInfo(name: "id", dataType: "int"),
                ColumnInfo(name: "email", dataType: "text"),
            ],
            rows: [["1", "alice@example.com"]]
        )

        let formatted = QueryResultTextFormatter.formatVertical(resultSet: resultSet)

        #expect(formatted.contains("1. row"))
        #expect(formatted.contains("id   : 1"))
        #expect(formatted.contains("email: alice@example.com"))
        #expect(formatted.contains("(1 row)"))
    }

    @Test func verticalFormatRendersNilAsNull() {
        let resultSet = QueryResultSet(
            columns: [ColumnInfo(name: "status", dataType: "text")],
            rows: [[nil]]
        )

        let formatted = QueryResultTextFormatter.formatVertical(resultSet: resultSet)

        #expect(formatted.contains("status: NULL"))
    }
}

import Testing
@testable import Echo

struct QueryResultDetailBuilderTests {
    private let columns = [
        ColumnInfo(name: "id", dataType: "bigint", isPrimaryKey: true, isNullable: false, maxLength: nil, comment: "Primary key"),
        ColumnInfo(name: "email", dataType: "varchar(255)", isPrimaryKey: false, isNullable: false, maxLength: 255, comment: "User email"),
        ColumnInfo(name: "nickname", dataType: "varchar(100)", isPrimaryKey: false, isNullable: true, maxLength: 100, comment: nil)
    ]

    @Test
    func recordDefaultsToFirstRow() {
        let rows = [
            ["1", "a@example.com", nil],
            ["2", "b@example.com", "bee"]
        ]

        let record = QueryResultDetailBuilder.record(columns: columns, rows: rows, selectedRowIndex: nil)

        #expect(record?.rowIndex == 0)
        #expect(record?.fields[0].value == "1")
        #expect(record?.fields[2].value == "NULL")
    }

    @Test
    func recordClampsRequestedRow() {
        let rows = [["1", "a@example.com", nil]]
        let record = QueryResultDetailBuilder.record(columns: columns, rows: rows, selectedRowIndex: 42)

        #expect(record?.rowIndex == 0)
    }

    @Test
    func fieldTypesDescribeMetadata() {
        let descriptors = QueryResultDetailBuilder.fieldTypes(columns: columns)

        #expect(descriptors.count == 3)
        #expect(descriptors[0].isPrimaryKey)
        #expect(descriptors[1].maxLengthDescription == "255")
        #expect(descriptors[2].comment.isEmpty)
    }

    @Test
    func resolvedRowIndexFallsBackSafely() {
        #expect(QueryResultDetailBuilder.resolvedRowIndex(nil, rowCount: 3) == 0)
        #expect(QueryResultDetailBuilder.resolvedRowIndex(-2, rowCount: 3) == 0)
        #expect(QueryResultDetailBuilder.resolvedRowIndex(7, rowCount: 3) == 2)
    }
}

import XCTest
@testable import Echo

final class PostgresSpoolDecodingTests: XCTestCase {
    func testOnlyDriverColumnTypesAreTreatedAsPostgres() {
        XCTAssertEqual(PostgresSpoolColumns.oid(for: "INTEGER(23)"), 23)
        XCTAssertEqual(PostgresSpoolColumns.oid(for: "TEXT[](1009)"), 1009)
        XCTAssertNil(PostgresSpoolColumns.oid(for: "varchar(50)"), "SQL Server type names are not Postgres OIDs")
        XCTAssertNil(PostgresSpoolColumns.oid(for: "int"))
        XCTAssertNil(PostgresSpoolColumns.oids(for: [ColumnInfo(name: "a", dataType: "INTEGER(23)"), ColumnInfo(name: "b", dataType: "nvarchar")]))
    }

    func testDecodesSpooledPostgresRows() {
        // Cells hold the server's text, as libpq returns it.
        var row = Data([0x01, 3, 0, 0, 0])
        row.append(contentsOf: Array("251".utf8))
        row.append(0x00)
        row.append(contentsOf: [0x01, 2, 0, 0, 0] + Array("hi".utf8))
        let values = PostgresSpoolColumns.decodeRow(row, oids: [23, 25, 25], formatter: .init())
        XCTAssertEqual(values, ["251", nil, "hi"])
    }

    func testPostgresArraysAndBitStringsAreText() {
        XCTAssertEqual(ResultGridValueClassifier.kind(forDataType: "INTEGER[](1007)", value: "{1,2}"), .text)
        XCTAssertEqual(ResultGridValueClassifier.kind(forDataType: "BIT(1560)", value: "1011"), .text)
        XCTAssertEqual(ResultGridValueClassifier.kind(forDataType: "INTEGER(23)", value: "1"), .numeric)
        XCTAssertEqual(ResultGridValueClassifier.kind(forDataType: "bit", value: "1"), .boolean, "SQL Server bit stays boolean")
    }
}

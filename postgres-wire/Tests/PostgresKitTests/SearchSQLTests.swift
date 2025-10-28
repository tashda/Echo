@testable import PostgresKit
import XCTest

final class SearchSQLTests: XCTestCase {
    func testTablesBuilder() {
        let sql = PostgresSearchSQL.tables(pattern: "foo", limit: 25)
        XCTAssertTrue(sql.contains("table_name"))
        XCTAssertTrue(sql.contains("ILIKE '%foo%'"))
        XCTAssertTrue(sql.contains("LIMIT 25"))
    }

    func testForeignKeysBuilder() {
        let sql = PostgresSearchSQL.foreignKeys(pattern: "bar", limit: 10)
        XCTAssertTrue(sql.contains("WITH fk_data"))
        XCTAssertTrue(sql.contains("ILIKE '%bar%'"))
        XCTAssertTrue(sql.contains("LIMIT 10"))
    }
}


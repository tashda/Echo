import XCTest
@testable import Echo

/// Tests SQL Server query execution through Echo's DatabaseSession layer.
final class MSSQLQueryTests: MSSQLDockerTestCase {

    // MARK: - Simple Queries

    func testSelectLiteral() async throws {
        let result = try await query("SELECT 42 AS number, 'hello' AS greeting")
        XCTAssertEqual(result.columns.count, 2)
        IntegrationTestHelpers.assertHasColumn(result, named: "number")
        IntegrationTestHelpers.assertHasColumn(result, named: "greeting")
        XCTAssertEqual(result.rows[0][0], "42")
        XCTAssertEqual(result.rows[0][1], "hello")
    }

    func testSelectMultipleRows() async throws {
        let result = try await query("""
            SELECT n FROM (VALUES (1),(2),(3),(4),(5)) AS t(n)
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 5)
    }

    func testSelectWithNulls() async throws {
        let result = try await query("SELECT NULL AS null_col, 1 AS not_null")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertNil(result.rows[0][0])
        XCTAssertEqual(result.rows[0][1], "1")
    }

    func testEmptyResultSet() async throws {
        try await withTempTable { tableName in
            let result = try await query("SELECT * FROM [\(tableName)]")
            XCTAssertEqual(result.rows.count, 0)
            XCTAssertFalse(result.columns.isEmpty)
        }
    }

    // MARK: - Execute Update

    func testInsertReturnsAffectedCount() async throws {
        try await withTempTable { tableName in
            let count = try await execute(
                "INSERT INTO [\(tableName)] (id, name, value) VALUES (1, 'test', 42)"
            )
            XCTAssertEqual(count, 1)
        }
    }

    func testMultipleInserts() async throws {
        try await withTempTable { tableName in
            let count = try await execute("""
                INSERT INTO [\(tableName)] (id, name, value)
                VALUES (1, 'a', 1), (2, 'b', 2), (3, 'c', 3)
            """)
            XCTAssertEqual(count, 3)
        }
    }

    func testUpdateReturnsAffectedCount() async throws {
        try await withTempTable { tableName in
            try await execute("""
                INSERT INTO [\(tableName)] (id, name, value)
                VALUES (1, 'a', 1), (2, 'b', 2), (3, 'c', 3)
            """)
            let count = try await execute(
                "UPDATE [\(tableName)] SET value = 99 WHERE value < 3"
            )
            XCTAssertEqual(count, 2)
        }
    }

    func testDeleteReturnsAffectedCount() async throws {
        try await withTempTable { tableName in
            try await execute("""
                INSERT INTO [\(tableName)] (id, name, value)
                VALUES (1, 'a', 1), (2, 'b', 2)
            """)
            let count = try await execute("DELETE FROM [\(tableName)] WHERE id = 1")
            XCTAssertEqual(count, 1)
        }
    }

    // MARK: - Paged Queries

    func testQueryWithPaging() async throws {
        try await withTempTable { tableName in
            for i in 1...20 {
                try await execute("INSERT INTO [\(tableName)] (id, name, value) VALUES (\(i), 'row\(i)', \(i))")
            }

            let page1 = try await session.queryWithPaging(
                "SELECT * FROM [\(tableName)] ORDER BY id",
                limit: 5, offset: 0
            )
            IntegrationTestHelpers.assertRowCount(page1, expected: 5)

            let page2 = try await session.queryWithPaging(
                "SELECT * FROM [\(tableName)] ORDER BY id",
                limit: 5, offset: 5
            )
            IntegrationTestHelpers.assertRowCount(page2, expected: 5)

            // Ensure different data
            XCTAssertNotEqual(page1.rows[0][0], page2.rows[0][0])
        }
    }

    func testQueryWithPagingBeyondData() async throws {
        try await withTempTable { tableName in
            try await execute("INSERT INTO [\(tableName)] (id, name, value) VALUES (1, 'only', 1)")
            let result = try await session.queryWithPaging(
                "SELECT * FROM [\(tableName)]",
                limit: 10, offset: 100
            )
            XCTAssertEqual(result.rows.count, 0)
        }
    }

    // MARK: - Multi-Result Sets

    func testMultipleResultSets() async throws {
        let result = try await query("""
            SELECT 1 AS first_result;
            SELECT 'a' AS col_a, 'b' AS col_b;
        """)
        // First result set
        XCTAssertEqual(result.columns.count, 1)
        XCTAssertEqual(result.rows.count, 1)

        // Additional result sets
        XCTAssertFalse(result.additionalResults.isEmpty, "Should have additional result sets")
        let second = result.additionalResults[0]
        XCTAssertEqual(second.columns.count, 2)
    }

    func testMultipleResultSetsWithDifferentShapes() async throws {
        let result = try await query("""
            SELECT 1 AS a, 2 AS b, 3 AS c;
            SELECT 'x' AS single;
            SELECT 100 AS num, 'hello' AS str;
        """)
        XCTAssertEqual(result.columns.count, 3, "First result has 3 columns")
        XCTAssertGreaterThanOrEqual(result.additionalResults.count, 2, "Should have 2+ additional result sets")
    }

    // MARK: - Large Queries

    func testLargeResultSet() async throws {
        let result = try await query("""
            SELECT TOP 1000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1000)
    }

    // MARK: - SQL with Special Characters

    func testUnicodeInResults() async throws {
        let result = try await query("SELECT N'日本語テスト' AS unicode_text")
        XCTAssertEqual(result.rows[0][0], "日本語テスト")
    }

    func testSpecialCharactersInStrings() async throws {
        let result = try await query("SELECT 'it''s a test' AS escaped, CHAR(9) AS tab_char")
        XCTAssertEqual(result.rows[0][0], "it's a test")
    }
}

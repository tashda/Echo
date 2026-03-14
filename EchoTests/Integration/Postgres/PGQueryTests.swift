import XCTest
@testable import Echo

/// Tests PostgreSQL query execution through Echo's DatabaseSession layer.
final class PGQueryTests: PostgresDockerTestCase {

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
            SELECT n FROM generate_series(1, 5) AS n
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
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            let result = try await query("SELECT * FROM public.\(tableName)")
            XCTAssertEqual(result.rows.count, 0)
            XCTAssertFalse(result.columns.isEmpty)
        }
    }

    func testSelectBooleanValues() async throws {
        let result = try await query("SELECT TRUE AS yes, FALSE AS no")
        XCTAssertEqual(result.rows.count, 1)
        // Boolean values come back as string representations
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    func testSelectNumericTypes() async throws {
        let result = try await query("""
            SELECT
                42::INTEGER AS int_val,
                3.14::NUMERIC(10,2) AS decimal_val,
                1.23e4::FLOAT AS float_val
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        IntegrationTestHelpers.assertHasColumn(result, named: "int_val")
        IntegrationTestHelpers.assertHasColumn(result, named: "decimal_val")
        IntegrationTestHelpers.assertHasColumn(result, named: "float_val")
    }

    // MARK: - Execute Update

    func testInsertReturnsAffectedCount() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            let count = try await execute(
                "INSERT INTO public.\(tableName) (name, value) VALUES ('test', 42)"
            )
            XCTAssertEqual(count, 1)
        }
    }

    func testMultipleInserts() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            let count = try await execute("""
                INSERT INTO public.\(tableName) (name, value)
                VALUES ('a', 1), ('b', 2), ('c', 3)
            """)
            XCTAssertEqual(count, 3)
        }
    }

    func testUpdateReturnsAffectedCount() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            try await execute("""
                INSERT INTO public.\(tableName) (name, value)
                VALUES ('a', 1), ('b', 2), ('c', 3)
            """)
            let count = try await execute(
                "UPDATE public.\(tableName) SET value = 99 WHERE value < 3"
            )
            XCTAssertEqual(count, 2)
        }
    }

    func testDeleteReturnsAffectedCount() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            try await execute("""
                INSERT INTO public.\(tableName) (name, value)
                VALUES ('a', 1), ('b', 2)
            """)
            let count = try await execute("DELETE FROM public.\(tableName) WHERE name = 'a'")
            XCTAssertEqual(count, 1)
        }
    }

    // MARK: - Paged Queries

    func testQueryWithPaging() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            for i in 1...20 {
                try await execute(
                    "INSERT INTO public.\(tableName) (name, value) VALUES ('row\(i)', \(i))"
                )
            }

            let page1 = try await session.queryWithPaging(
                "SELECT * FROM public.\(tableName) ORDER BY id",
                limit: 5, offset: 0
            )
            IntegrationTestHelpers.assertRowCount(page1, expected: 5)

            let page2 = try await session.queryWithPaging(
                "SELECT * FROM public.\(tableName) ORDER BY id",
                limit: 5, offset: 5
            )
            IntegrationTestHelpers.assertRowCount(page2, expected: 5)

            // Ensure different data
            XCTAssertNotEqual(page1.rows[0][0], page2.rows[0][0])
        }
    }

    func testQueryWithPagingBeyondData() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            try await execute(
                "INSERT INTO public.\(tableName) (name, value) VALUES ('only', 1)"
            )
            let result = try await session.queryWithPaging(
                "SELECT * FROM public.\(tableName)",
                limit: 10, offset: 100
            )
            XCTAssertEqual(result.rows.count, 0)
        }
    }

    // MARK: - Large Result Sets

    func testLargeResultSet() async throws {
        let result = try await query("""
            SELECT n FROM generate_series(1, 1000) AS n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1000)
    }

    func testLargeResultSetWithMultipleColumns() async throws {
        let result = try await query("""
            SELECT
                n AS id,
                'row_' || n AS name,
                n * 10 AS computed_value
            FROM generate_series(1, 500) AS n
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 500)
        XCTAssertEqual(result.columns.count, 3)
    }

    // MARK: - Unicode and Special Characters

    func testUnicodeInResults() async throws {
        let result = try await query("SELECT '日本語テスト' AS unicode_text")
        XCTAssertEqual(result.rows[0][0], "日本語テスト")
    }

    func testUnicodeEmojis() async throws {
        let result = try await query("SELECT '🎉🚀💻' AS emoji_text")
        XCTAssertEqual(result.rows[0][0], "🎉🚀💻")
    }

    func testSpecialCharactersInStrings() async throws {
        let result = try await query("SELECT 'it''s a test' AS escaped")
        XCTAssertEqual(result.rows[0][0], "it's a test")
    }

    func testBackslashAndNewlines() async throws {
        let result = try await query("""
            SELECT E'line1\\nline2' AS multiline, E'path\\\\to\\\\file' AS backslash
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    func testCyrillicAndArabicText() async throws {
        let result = try await query("""
            SELECT 'Привет мир' AS russian, 'مرحبا بالعالم' AS arabic
        """)
        XCTAssertEqual(result.rows[0][0], "Привет мир")
        XCTAssertEqual(result.rows[0][1], "مرحبا بالعالم")
    }

    func testUnicodeStorageAndRetrieval() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            try await execute(
                "INSERT INTO public.\(tableName) (name, value) VALUES ('こんにちは世界', 1)"
            )
            let result = try await query(
                "SELECT name FROM public.\(tableName) WHERE value = 1"
            )
            XCTAssertEqual(result.rows[0][0], "こんにちは世界")
        }
    }

    // MARK: - Date and Time

    func testTimestampQuery() async throws {
        let result = try await query("SELECT NOW() AS current_time")
        XCTAssertNotNil(result.rows[0][0])
        IntegrationTestHelpers.assertHasColumn(result, named: "current_time")
    }

    // MARK: - JSON

    func testJsonQuery() async throws {
        let result = try await query("""
            SELECT '{"key": "value", "num": 42}'::JSONB AS json_data
        """)
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Array Types

    func testArrayQuery() async throws {
        let result = try await query("SELECT ARRAY[1, 2, 3] AS int_array")
        XCTAssertNotNil(result.rows[0][0])
        IntegrationTestHelpers.assertHasColumn(result, named: "int_array")
    }
}

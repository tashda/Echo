import XCTest
@testable import Echo

/// Tests PostgreSQL string and character data type round-trips through Echo's DatabaseSession layer.
final class PGDataTypeStringTests: PostgresDockerTestCase {

    // MARK: - CHAR(n)

    func testCharType() async throws {
        let result = try await query("SELECT 'hello'::CHAR(10) AS val")
        XCTAssertNotNil(result.rows[0][0])
        // CHAR pads with spaces to the specified length
        XCTAssertTrue(result.rows[0][0]?.contains("hello") ?? false)
    }

    func testCharExactLength() async throws {
        let result = try await query("SELECT 'abc'::CHAR(3) AS val")
        XCTAssertEqual(result.rows[0][0], "abc")
    }

    func testCharPadding() async throws {
        let result = try await query("SELECT 'ab'::CHAR(5) AS val")
        XCTAssertNotNil(result.rows[0][0])
        // Should be "ab   " (padded with spaces)
        let val = result.rows[0][0]!
        XCTAssertTrue(val.hasPrefix("ab"), "CHAR should start with 'ab', got '\(val)'")
    }

    func testCharSingleChar() async throws {
        let result = try await query("SELECT 'X'::CHAR(1) AS val")
        XCTAssertEqual(result.rows[0][0], "X")
    }

    // MARK: - VARCHAR(n)

    func testVarcharType() async throws {
        let result = try await query("SELECT 'hello world'::VARCHAR(100) AS val")
        XCTAssertEqual(result.rows[0][0], "hello world")
    }

    func testVarcharMaxLength() async throws {
        let str = String(repeating: "a", count: 255)
        let result = try await query("SELECT '\(str)'::VARCHAR(255) AS val")
        XCTAssertEqual(result.rows[0][0], str)
    }

    func testVarcharNoTruncation() async throws {
        let result = try await query("SELECT 'short'::VARCHAR(1000) AS val")
        XCTAssertEqual(result.rows[0][0], "short")
    }

    // MARK: - TEXT

    func testTextType() async throws {
        let result = try await query("SELECT 'arbitrary length text'::TEXT AS val")
        XCTAssertEqual(result.rows[0][0], "arbitrary length text")
    }

    func testTextVeryLong() async throws {
        let longText = String(repeating: "x", count: 10_000)
        let result = try await query("SELECT '\(longText)'::TEXT AS val")
        XCTAssertEqual(result.rows[0][0]?.count, 10_000)
    }

    func testTextWithRepeatFunction() async throws {
        let result = try await query("SELECT repeat('ab', 500) AS val")
        XCTAssertEqual(result.rows[0][0]?.count, 1000)
    }

    // MARK: - Empty Strings

    func testEmptyText() async throws {
        let result = try await query("SELECT ''::TEXT AS val")
        XCTAssertEqual(result.rows[0][0], "")
    }

    func testEmptyVarchar() async throws {
        let result = try await query("SELECT ''::VARCHAR(10) AS val")
        XCTAssertEqual(result.rows[0][0], "")
    }

    func testEmptyStringIsNotNull() async throws {
        let result = try await query("SELECT '' IS NULL AS is_null")
        let val = result.rows[0][0] ?? ""
        XCTAssertTrue(val == "f" || val == "false", "Empty string should not be NULL in PostgreSQL")
    }

    // MARK: - Unicode / Multi-byte Strings

    func testUnicodeJapanese() async throws {
        let result = try await query("SELECT E'\\u65e5\\u672c\\u8a9e\\u30c6\\u30b9\\u30c8'::TEXT AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testUnicodeChinese() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            try await execute("INSERT INTO \(tableName) (name, value) VALUES ('\u{4f60}\u{597d}\u{4e16}\u{754c}', 1)")
            let result = try await query("SELECT name FROM \(tableName) WHERE value = 1")
            XCTAssertEqual(result.rows[0][0], "\u{4f60}\u{597d}\u{4e16}\u{754c}")
        }
    }

    func testUnicodeCyrillic() async throws {
        let result = try await query("SELECT '\u{041f}\u{0440}\u{0438}\u{0432}\u{0435}\u{0442}'::TEXT AS val")
        XCTAssertEqual(result.rows[0][0], "\u{041f}\u{0440}\u{0438}\u{0432}\u{0435}\u{0442}")
    }

    func testUnicodeArabic() async throws {
        let result = try await query("SELECT '\u{0645}\u{0631}\u{062d}\u{0628}\u{0627}'::TEXT AS val")
        XCTAssertEqual(result.rows[0][0], "\u{0645}\u{0631}\u{062d}\u{0628}\u{0627}")
    }

    func testUnicodeEmoji() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            try await execute("INSERT INTO \(tableName) (name, value) VALUES ('\u{1F680}\u{1F4BB}\u{2705}', 1)")
            let result = try await query("SELECT name FROM \(tableName) WHERE value = 1")
            XCTAssertEqual(result.rows[0][0], "\u{1F680}\u{1F4BB}\u{2705}")
        }
    }

    func testUnicodeAccentedCharacters() async throws {
        let result = try await query("SELECT 'caf\u{00e9} na\u{00ef}ve r\u{00e9}sum\u{00e9}'::TEXT AS val")
        XCTAssertEqual(result.rows[0][0], "caf\u{00e9} na\u{00ef}ve r\u{00e9}sum\u{00e9}")
    }

    func testUnicodeMixedScripts() async throws {
        let mixed = "Hello \u{4e16}\u{754c} \u{041c}\u{0438}\u{0440}"
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            try await execute("INSERT INTO \(tableName) (name, value) VALUES ('\(mixed)', 1)")
            let result = try await query("SELECT name FROM \(tableName) WHERE value = 1")
            XCTAssertEqual(result.rows[0][0], mixed)
        }
    }

    // MARK: - Special Characters

    func testSingleQuoteEscape() async throws {
        let result = try await query("SELECT 'it''s a test'::TEXT AS val")
        XCTAssertEqual(result.rows[0][0], "it's a test")
    }

    func testBackslash() async throws {
        let result = try await query("""
            SELECT E'path\\\\to\\\\file'::TEXT AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("\\") ?? false)
    }

    func testNewlineInString() async throws {
        let result = try await query("SELECT E'line1\\nline2'::TEXT AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("\n") ?? false)
    }

    func testTabInString() async throws {
        let result = try await query("SELECT E'col1\\tcol2'::TEXT AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("\t") ?? false)
    }

    // MARK: - Name Type

    func testNameType() async throws {
        let result = try await query("SELECT 'pg_catalog'::NAME AS val")
        XCTAssertEqual(result.rows[0][0], "pg_catalog")
    }

    func testNameTypeFromSystemCatalog() async throws {
        let result = try await query("SELECT typname FROM pg_type WHERE typname = 'int4'")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "int4")
    }

    // MARK: - citext (Extension)

    func testCitextIfAvailable() async throws {
        // Try to create the extension; skip if unavailable
        do {
            try await execute("CREATE EXTENSION IF NOT EXISTS citext")
        } catch {
            throw XCTSkip("citext extension not available")
        }

        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name CITEXT, value INTEGER") { tableName in
            try await execute("INSERT INTO \(tableName) (name, value) VALUES ('Hello', 1)")

            // citext comparisons are case-insensitive
            let result = try await query("SELECT name FROM \(tableName) WHERE name = 'hello'")
            IntegrationTestHelpers.assertRowCount(result, expected: 1)
            XCTAssertEqual(result.rows[0][0], "Hello")
        }
    }

    // MARK: - NULL Handling

    func testNullText() async throws {
        let result = try await query("SELECT NULL::TEXT AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullVarchar() async throws {
        let result = try await query("SELECT NULL::VARCHAR(100) AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullChar() async throws {
        let result = try await query("SELECT NULL::CHAR(10) AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullName() async throws {
        let result = try await query("SELECT NULL::NAME AS val")
        XCTAssertNil(result.rows[0][0])
    }

    // MARK: - Table Round-Trip

    func testStringRoundTripAllTypes() async throws {
        try await withTempTable(
            columns: """
                id SERIAL PRIMARY KEY,
                char_val CHAR(20),
                varchar_val VARCHAR(200),
                text_val TEXT
            """
        ) { tableName in
            try await execute("""
                INSERT INTO \(tableName)
                (char_val, varchar_val, text_val)
                VALUES ('fixed', 'variable length', 'unlimited text content here')
            """)

            let result = try await query("SELECT * FROM \(tableName)")
            IntegrationTestHelpers.assertRowCount(result, expected: 1)
            XCTAssertEqual(result.columns.count, 4)

            // char_val is padded
            XCTAssertTrue(result.rows[0][1]?.contains("fixed") ?? false)
            XCTAssertEqual(result.rows[0][2], "variable length")
            XCTAssertEqual(result.rows[0][3], "unlimited text content here")
        }
    }

    func testStringRoundTripWithUnicode() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, value INTEGER") { tableName in
            let testStrings = [
                "ASCII only",
                "caf\u{00e9}",
                "\u{65e5}\u{672c}\u{8a9e}",
                "\u{041f}\u{0440}\u{0438}\u{0432}\u{0435}\u{0442}",
                "\u{1F600}\u{1F680}"
            ]

            for (index, str) in testStrings.enumerated() {
                try await execute("INSERT INTO \(tableName) (name, value) VALUES ('\(str)', \(index))")
            }

            let result = try await query("SELECT name, value FROM \(tableName) ORDER BY value")
            IntegrationTestHelpers.assertRowCount(result, expected: testStrings.count)

            for (index, str) in testStrings.enumerated() {
                XCTAssertEqual(result.rows[index][0], str, "Row \(index) should match")
            }
        }
    }

    func testStringRoundTripWithNulls() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, char_val CHAR(10), varchar_val VARCHAR(50), text_val TEXT"
        ) { tableName in
            try await execute("""
                INSERT INTO \(tableName) (char_val, varchar_val, text_val)
                VALUES (NULL, NULL, NULL)
            """)

            let result = try await query("SELECT char_val, varchar_val, text_val FROM \(tableName)")
            IntegrationTestHelpers.assertRowCount(result, expected: 1)
            XCTAssertNil(result.rows[0][0])
            XCTAssertNil(result.rows[0][1])
            XCTAssertNil(result.rows[0][2])
        }
    }

    // MARK: - String Functions

    func testStringLength() async throws {
        let result = try await query("SELECT length('hello'::TEXT) AS len")
        XCTAssertEqual(result.rows[0][0], "5")
    }

    func testStringConcatenation() async throws {
        let result = try await query("SELECT 'hello' || ' ' || 'world' AS val")
        XCTAssertEqual(result.rows[0][0], "hello world")
    }

    func testStringUpper() async throws {
        let result = try await query("SELECT upper('hello') AS val")
        XCTAssertEqual(result.rows[0][0], "HELLO")
    }

    func testStringLower() async throws {
        let result = try await query("SELECT lower('HELLO') AS val")
        XCTAssertEqual(result.rows[0][0], "hello")
    }
}

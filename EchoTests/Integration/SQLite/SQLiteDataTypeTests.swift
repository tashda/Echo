import XCTest
@testable import Echo

/// Tests SQLite data type handling through Echo's DatabaseSession layer.
final class SQLiteDataTypeTests: XCTestCase {

    private var session: DatabaseSession!

    override func setUp() async throws {
        try await super.setUp()
        let factory = SQLiteFactory()
        session = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: "",
                password: ""
            ),
            connectTimeoutSeconds: 5
        )
    }

    override func tearDown() async throws {
        if let session { await session.close() }
        session = nil
        try await super.tearDown()
    }

    // MARK: - Integer Affinity

    func testIntegerType() async throws {
        let result = try await session.simpleQuery("SELECT 42 AS val")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    func testLargeInteger() async throws {
        let result = try await session.simpleQuery("SELECT 9223372036854775807 AS val")
        XCTAssertEqual(result.rows[0][0], "9223372036854775807")
    }

    func testNegativeInteger() async throws {
        let result = try await session.simpleQuery("SELECT -42 AS val")
        XCTAssertEqual(result.rows[0][0], "-42")
    }

    // MARK: - Real Affinity

    func testRealType() async throws {
        let result = try await session.simpleQuery("SELECT 3.14 AS val")
        XCTAssertNotNil(result.rows[0][0])
        let value = Double(result.rows[0][0] ?? "0") ?? 0
        XCTAssertEqual(value, 3.14, accuracy: 0.01)
    }

    func testScientificNotation() async throws {
        let result = try await session.simpleQuery("SELECT 1.5e10 AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Text Affinity

    func testTextType() async throws {
        let result = try await session.simpleQuery("SELECT 'hello world' AS val")
        XCTAssertEqual(result.rows[0][0], "hello world")
    }

    func testEmptyString() async throws {
        let result = try await session.simpleQuery("SELECT '' AS val")
        XCTAssertEqual(result.rows[0][0], "")
    }

    func testUnicodeText() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t (val TEXT)")
        _ = try await session.executeUpdate("INSERT INTO t VALUES ('日本語 café émojis')")
        let result = try await session.simpleQuery("SELECT val FROM t")
        XCTAssertEqual(result.rows[0][0], "日本語 café émojis")
    }

    // MARK: - Blob Affinity

    func testBlobType() async throws {
        let result = try await session.simpleQuery("SELECT X'48656C6C6F' AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - NULL

    func testNullValue() async throws {
        let result = try await session.simpleQuery("SELECT NULL AS val")
        XCTAssertNil(result.rows[0][0])
    }

    // MARK: - Date/Time (stored as text/int/real in SQLite)

    func testDateAsText() async throws {
        let result = try await session.simpleQuery("SELECT date('2024-03-15') AS val")
        XCTAssertEqual(result.rows[0][0], "2024-03-15")
    }

    func testDateTimeAsText() async throws {
        let result = try await session.simpleQuery("SELECT datetime('2024-03-15 14:30:00') AS val")
        XCTAssertEqual(result.rows[0][0], "2024-03-15 14:30:00")
    }

    // MARK: - Round-Trip Through Table

    func testAllTypesRoundTrip() async throws {
        _ = try await session.executeUpdate("""
            CREATE TABLE type_test (
                int_val INTEGER,
                real_val REAL,
                text_val TEXT,
                blob_val BLOB,
                null_val TEXT
            )
        """)
        _ = try await session.executeUpdate("""
            INSERT INTO type_test VALUES (42, 3.14, 'hello', X'DEADBEEF', NULL)
        """)

        let result = try await session.simpleQuery("SELECT * FROM type_test")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0][0], "42")
        XCTAssertNotNil(result.rows[0][1]) // real
        XCTAssertEqual(result.rows[0][2], "hello")
        XCTAssertNotNil(result.rows[0][3]) // blob
        XCTAssertNil(result.rows[0][4]) // null
    }

    // MARK: - Boolean (stored as integer in SQLite)

    func testBooleanValues() async throws {
        _ = try await session.executeUpdate("CREATE TABLE bools (val BOOLEAN)")
        _ = try await session.executeUpdate("INSERT INTO bools VALUES (1)")
        _ = try await session.executeUpdate("INSERT INTO bools VALUES (0)")

        let result = try await session.simpleQuery("SELECT val FROM bools ORDER BY val")
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0][0], "0")
        XCTAssertEqual(result.rows[1][0], "1")
    }
}

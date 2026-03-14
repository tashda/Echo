import XCTest
@testable import Echo

/// Tests SQLite query execution through Echo's DatabaseSession layer.
final class SQLiteQueryTests: XCTestCase {

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

    // MARK: - Simple Queries

    func testSelectLiteral() async throws {
        let result = try await session.simpleQuery("SELECT 42 AS number, 'hello' AS greeting")
        XCTAssertEqual(result.columns.count, 2)
        XCTAssertEqual(result.rows[0][0], "42")
        XCTAssertEqual(result.rows[0][1], "hello")
    }

    func testSelectMultipleRows() async throws {
        _ = try await session.executeUpdate("CREATE TABLE nums (n INTEGER)")
        for i in 1...5 {
            _ = try await session.executeUpdate("INSERT INTO nums VALUES (\(i))")
        }
        let result = try await session.simpleQuery("SELECT n FROM nums ORDER BY n")
        XCTAssertEqual(result.rows.count, 5)
    }

    func testSelectWithNulls() async throws {
        let result = try await session.simpleQuery("SELECT NULL AS null_col, 1 AS not_null")
        XCTAssertNil(result.rows[0][0])
        XCTAssertEqual(result.rows[0][1], "1")
    }

    func testEmptyResultSet() async throws {
        _ = try await session.executeUpdate("CREATE TABLE empty_t (id INTEGER)")
        let result = try await session.simpleQuery("SELECT * FROM empty_t")
        XCTAssertEqual(result.rows.count, 0)
    }

    // MARK: - Execute Update

    func testInsertReturnsCount() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t (id INTEGER, name TEXT)")
        let count = try await session.executeUpdate("INSERT INTO t VALUES (1, 'a')")
        XCTAssertEqual(count, 1)
    }

    func testUpdateReturnsCount() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t (id INTEGER, val INTEGER)")
        _ = try await session.executeUpdate("INSERT INTO t VALUES (1, 10), (2, 20), (3, 30)")
        let count = try await session.executeUpdate("UPDATE t SET val = 99 WHERE val < 25")
        XCTAssertEqual(count, 2)
    }

    func testDeleteReturnsCount() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t (id INTEGER)")
        _ = try await session.executeUpdate("INSERT INTO t VALUES (1), (2), (3)")
        let count = try await session.executeUpdate("DELETE FROM t WHERE id > 1")
        XCTAssertEqual(count, 2)
    }

    // MARK: - Paged Queries

    func testQueryWithPaging() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t (id INTEGER)")
        for i in 1...20 {
            _ = try await session.executeUpdate("INSERT INTO t VALUES (\(i))")
        }

        let page1 = try await session.queryWithPaging("SELECT id FROM t ORDER BY id", limit: 5, offset: 0)
        XCTAssertEqual(page1.rows.count, 5)
        XCTAssertEqual(page1.rows[0][0], "1")

        let page2 = try await session.queryWithPaging("SELECT id FROM t ORDER BY id", limit: 5, offset: 5)
        XCTAssertEqual(page2.rows.count, 5)
        XCTAssertEqual(page2.rows[0][0], "6")
    }

    // MARK: - Unicode

    func testUnicodeStrings() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t (text_val TEXT)")
        _ = try await session.executeUpdate("INSERT INTO t VALUES ('日本語テスト')")
        let result = try await session.simpleQuery("SELECT text_val FROM t")
        XCTAssertEqual(result.rows[0][0], "日本語テスト")
    }
}

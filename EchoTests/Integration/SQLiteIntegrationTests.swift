import XCTest
@testable import Echo

final class SQLiteIntegrationTests: XCTestCase {

    private func makeInMemorySession() async throws -> DatabaseSession {
        let factory = SQLiteFactory()
        return try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(username: "", password: nil)
        )
    }

    // MARK: - Basic Queries

    func testSimpleQuerySelect1() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1 AS value")
        XCTAssertEqual(result.columns.count, 1)
        XCTAssertEqual(result.columns[0].name, "value")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0][0], "1")
    }

    // MARK: - Table Creation and Query

    func testCreateTableAndInsert() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("""
            CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT
            )
        """)

        let insertCount = try await session.executeUpdate("""
            INSERT INTO users (name, email) VALUES
            ('Alice', 'alice@example.com'),
            ('Bob', 'bob@example.com'),
            ('Charlie', NULL)
        """)
        XCTAssertEqual(insertCount, 3)

        let result = try await session.simpleQuery("SELECT * FROM users ORDER BY id")
        XCTAssertEqual(result.rows.count, 3)
        XCTAssertEqual(result.rows[0][1], "Alice")
        XCTAssertEqual(result.rows[2][2], nil) // Charlie's email is NULL
    }

    // MARK: - Schema Discovery

    func testListTablesAndViews() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE orders (id INTEGER PRIMARY KEY, product TEXT)")
        _ = try await session.executeUpdate("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)")
        _ = try await session.executeUpdate("CREATE VIEW order_view AS SELECT * FROM orders")

        let objects = try await session.listTablesAndViews(schema: nil)
        let names = objects.map(\.name)

        XCTAssertTrue(names.contains("orders"))
        XCTAssertTrue(names.contains("items"))
        XCTAssertTrue(names.contains("order_view"))
    }

    func testGetTableSchema() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("""
            CREATE TABLE products (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                price REAL,
                quantity INTEGER DEFAULT 0
            )
        """)

        let columns = try await session.getTableSchema("products", schemaName: nil)
        XCTAssertEqual(columns.count, 4)

        let names = columns.map(\.name)
        XCTAssertTrue(names.contains("id"))
        XCTAssertTrue(names.contains("name"))
        XCTAssertTrue(names.contains("price"))
        XCTAssertTrue(names.contains("quantity"))
    }

    // MARK: - Query With Paging

    func testQueryWithPaging() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE nums (n INTEGER)")
        for i in 1...20 {
            _ = try await session.executeUpdate("INSERT INTO nums VALUES (\(i))")
        }

        let page1 = try await session.queryWithPaging("SELECT n FROM nums ORDER BY n", limit: 5, offset: 0)
        XCTAssertEqual(page1.rows.count, 5)
        XCTAssertEqual(page1.rows[0][0], "1")

        let page2 = try await session.queryWithPaging("SELECT n FROM nums ORDER BY n", limit: 5, offset: 5)
        XCTAssertEqual(page2.rows.count, 5)
        XCTAssertEqual(page2.rows[0][0], "6")
    }

    // MARK: - Data Type Round-Trips

    func testDataTypeRoundTrips() async throws {
        let session = try await makeInMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("""
            CREATE TABLE types_test (
                int_col INTEGER,
                real_col REAL,
                text_col TEXT,
                blob_col BLOB
            )
        """)

        _ = try await session.executeUpdate("""
            INSERT INTO types_test VALUES (42, 3.14, 'hello', X'DEADBEEF')
        """)

        let result = try await session.simpleQuery("SELECT * FROM types_test")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0][0], "42")
        XCTAssertEqual(result.rows[0][2], "hello")
    }
}

import XCTest
@testable import Echo

/// Tests SQLite table DDL operations through Echo's DatabaseSession layer.
final class SQLiteTableOperationsTests: XCTestCase {

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

    // MARK: - Create Table

    func testCreateTable() async throws {
        _ = try await session.executeUpdate("CREATE TABLE test_t (id INTEGER PRIMARY KEY, name TEXT)")
        let objects = try await session.listTablesAndViews(schema: nil)
        IntegrationTestHelpers.assertContainsObject(objects, name: "test_t")
    }

    func testCreateTableWithConstraints() async throws {
        _ = try await session.executeUpdate("""
            CREATE TABLE constrained (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT UNIQUE,
                age INTEGER CHECK (age >= 0)
            )
        """)

        let details = try await session.getTableStructureDetails(schema: "main", table: "constrained")
        XCTAssertGreaterThanOrEqual(details.columns.count, 4)
    }

    // MARK: - Rename Table (via executeUpdate — SQLite adapter doesn't implement renameTable)

    func testRenameTable() async throws {
        _ = try await session.executeUpdate("CREATE TABLE old_name (id INTEGER)")
        _ = try await session.executeUpdate("ALTER TABLE old_name RENAME TO new_name")

        let objects = try await session.listTablesAndViews(schema: nil)
        IntegrationTestHelpers.assertContainsObject(objects, name: "new_name")
        let oldExists = objects.contains { $0.name == "old_name" }
        XCTAssertFalse(oldExists)
    }

    // MARK: - Drop Table (via executeUpdate — SQLite adapter doesn't implement dropTable)

    func testDropTable() async throws {
        _ = try await session.executeUpdate("CREATE TABLE drop_me (id INTEGER)")
        _ = try await session.executeUpdate("DROP TABLE drop_me")

        let objects = try await session.listTablesAndViews(schema: nil)
        let exists = objects.contains { $0.name == "drop_me" }
        XCTAssertFalse(exists)
    }

    func testDropTableIfExistsNonexistent() async throws {
        // Should not throw
        _ = try await session.executeUpdate("DROP TABLE IF EXISTS nonexistent_xyz")
    }

    // MARK: - Truncate Table (via DELETE — SQLite has no TRUNCATE)

    func testTruncateTable() async throws {
        _ = try await session.executeUpdate("CREATE TABLE trunc_t (id INTEGER, name TEXT)")
        _ = try await session.executeUpdate("INSERT INTO trunc_t VALUES (1, 'a'), (2, 'b')")

        _ = try await session.executeUpdate("DELETE FROM trunc_t")

        let result = try await session.simpleQuery("SELECT COUNT(*) FROM trunc_t")
        XCTAssertEqual(result.rows[0][0], "0")
    }

    // MARK: - Full Lifecycle

    func testCreateInsertSelectDrop() async throws {
        _ = try await session.executeUpdate("""
            CREATE TABLE lifecycle (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                score REAL
            )
        """)

        _ = try await session.executeUpdate("INSERT INTO lifecycle VALUES (1, 'Alice', 95.5)")
        _ = try await session.executeUpdate("INSERT INTO lifecycle VALUES (2, 'Bob', 87.3)")

        let result = try await session.simpleQuery("SELECT * FROM lifecycle ORDER BY id")
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0][1], "Alice")

        _ = try await session.executeUpdate("DROP TABLE lifecycle")
    }
}

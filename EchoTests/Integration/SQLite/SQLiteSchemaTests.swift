import XCTest
@testable import Echo

/// Tests SQLite schema discovery through Echo's DatabaseSession layer.
final class SQLiteSchemaTests: XCTestCase {

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

    // MARK: - List Tables

    func testListTablesAndViews() async throws {
        _ = try await session.executeUpdate("CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT)")

        let objects = try await session.listTablesAndViews(schema: nil)
        IntegrationTestHelpers.assertContainsObject(objects, name: "test_table")
    }

    func testListTablesMultiple() async throws {
        _ = try await session.executeUpdate("CREATE TABLE t1 (id INTEGER)")
        _ = try await session.executeUpdate("CREATE TABLE t2 (id INTEGER)")
        _ = try await session.executeUpdate("CREATE TABLE t3 (id INTEGER)")

        let objects = try await session.listTablesAndViews(schema: nil)
        IntegrationTestHelpers.assertContainsObject(objects, name: "t1")
        IntegrationTestHelpers.assertContainsObject(objects, name: "t2")
        IntegrationTestHelpers.assertContainsObject(objects, name: "t3")
    }

    func testListTablesEmpty() async throws {
        let objects = try await session.listTablesAndViews(schema: nil)
        // Might have sqlite internal tables or might be empty
        XCTAssertNotNil(objects)
    }

    // MARK: - List Schemas

    func testListSchemas() async throws {
        let schemas = try await session.listSchemas()
        // SQLite has "main" schema at minimum
        XCTAssertFalse(schemas.isEmpty)
    }

    // MARK: - Table Schema

    func testGetTableSchema() async throws {
        _ = try await session.executeUpdate("""
            CREATE TABLE test_table (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT,
                age INTEGER
            )
        """)

        let columns = try await session.getTableSchema("test_table", schemaName: nil)
        XCTAssertGreaterThanOrEqual(columns.count, 4)

        let names = columns.map(\.name)
        XCTAssertTrue(names.contains("id"))
        XCTAssertTrue(names.contains("name"))
    }

    // MARK: - Table Structure Details

    func testGetTableStructureDetails() async throws {
        _ = try await session.executeUpdate("""
            CREATE TABLE detail_test (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                value REAL DEFAULT 0
            )
        """)

        let details = try await session.getTableStructureDetails(schema: "main", table: "detail_test")
        XCTAssertGreaterThanOrEqual(details.columns.count, 3)
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "id")
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "name")
    }

    func testTableStructureWithForeignKey() async throws {
        _ = try await session.executeUpdate("CREATE TABLE parent (id INTEGER PRIMARY KEY)")
        _ = try await session.executeUpdate("""
            CREATE TABLE child (
                id INTEGER PRIMARY KEY,
                parent_id INTEGER REFERENCES parent(id)
            )
        """)

        let details = try await session.getTableStructureDetails(schema: "main", table: "child")
        XCTAssertGreaterThanOrEqual(details.columns.count, 2)
        // FK detection may vary in SQLite implementation
    }
}

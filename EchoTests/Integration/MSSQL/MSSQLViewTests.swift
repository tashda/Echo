import XCTest
@testable import Echo

/// Tests SQL Server view operations through Echo's DatabaseSession layer.
final class MSSQLViewTests: MSSQLDockerTestCase {

    // MARK: - Create View

    func testCreateView() async throws {
        let tableName = uniqueTableName()
        let viewName = uniqueTableName(prefix: "v")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100), active BIT DEFAULT 1)")
        try await execute("CREATE VIEW [\(viewName)] AS SELECT id, name FROM [\(tableName)] WHERE active = 1")
        cleanupSQL(
            "DROP VIEW [\(viewName)]",
            "DROP TABLE [\(tableName)]"
        )

        let objects = try await session.listTablesAndViews(schema: "dbo")
        IntegrationTestHelpers.assertContainsObject(objects, name: viewName, type: .view)
    }

    func testQueryThroughView() async throws {
        let tableName = uniqueTableName()
        let viewName = uniqueTableName(prefix: "v")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100), active BIT)")
        try await execute("INSERT INTO [\(tableName)] VALUES (1, 'Alice', 1), (2, 'Bob', 0), (3, 'Carol', 1)")
        try await execute("CREATE VIEW [\(viewName)] AS SELECT id, name FROM [\(tableName)] WHERE active = 1")
        cleanupSQL(
            "DROP VIEW [\(viewName)]",
            "DROP TABLE [\(tableName)]"
        )

        let result = try await query("SELECT * FROM [\(viewName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertEqual(result.rows[0][1], "Alice")
        XCTAssertEqual(result.rows[1][1], "Carol")
    }

    // MARK: - Alter View

    func testAlterView() async throws {
        let tableName = uniqueTableName()
        let viewName = uniqueTableName(prefix: "v")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100), email NVARCHAR(200))")
        try await execute("CREATE VIEW [\(viewName)] AS SELECT id, name FROM [\(tableName)]")
        cleanupSQL(
            "DROP VIEW [\(viewName)]",
            "DROP TABLE [\(tableName)]"
        )

        // Alter to include email
        try await execute("ALTER VIEW [\(viewName)] AS SELECT id, name, email FROM [\(tableName)]")

        let definition = try await session.getObjectDefinition(
            objectName: viewName, schemaName: "dbo", objectType: .view
        )
        XCTAssertTrue(definition.lowercased().contains("email"))
    }

    // MARK: - Drop View

    func testDropView() async throws {
        let tableName = uniqueTableName()
        let viewName = uniqueTableName(prefix: "v")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY)")
        try await execute("CREATE VIEW [\(viewName)] AS SELECT id FROM [\(tableName)]")
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("DROP VIEW [\(viewName)]")

        let objects = try await session.listTablesAndViews(schema: "dbo")
        let exists = objects.contains { $0.name.caseInsensitiveCompare(viewName) == .orderedSame }
        XCTAssertFalse(exists)
    }

    // MARK: - View Definition

    func testGetViewDefinition() async throws {
        let tableName = uniqueTableName()
        let viewName = uniqueTableName(prefix: "v")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100))")
        try await execute("CREATE VIEW [\(viewName)] AS SELECT id, name FROM [\(tableName)] WHERE id > 0")
        cleanupSQL(
            "DROP VIEW [\(viewName)]",
            "DROP TABLE [\(tableName)]"
        )

        let definition = try await session.getObjectDefinition(
            objectName: viewName, schemaName: "dbo", objectType: .view
        )
        XCTAssertFalse(definition.isEmpty)
        XCTAssertTrue(definition.lowercased().contains("select"))
    }

    // MARK: - View with Joins

    func testViewWithJoin() async throws {
        let t1 = uniqueTableName(prefix: "dept")
        let t2 = uniqueTableName(prefix: "emp")
        let viewName = uniqueTableName(prefix: "v")
        try await execute("CREATE TABLE [\(t1)] (id INT PRIMARY KEY, name NVARCHAR(100))")
        try await execute("CREATE TABLE [\(t2)] (id INT PRIMARY KEY, dept_id INT, name NVARCHAR(100))")
        try await execute("INSERT INTO [\(t1)] VALUES (1, 'Engineering')")
        try await execute("INSERT INTO [\(t2)] VALUES (1, 1, 'Alice'), (2, 1, 'Bob')")
        try await execute("""
            CREATE VIEW [\(viewName)] AS
            SELECT e.name AS employee, d.name AS department
            FROM [\(t2)] e JOIN [\(t1)] d ON e.dept_id = d.id
        """)
        cleanupSQL(
            "DROP VIEW [\(viewName)]",
            "DROP TABLE [\(t2)]",
            "DROP TABLE [\(t1)]"
        )

        let result = try await query("SELECT * FROM [\(viewName)]")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }
}

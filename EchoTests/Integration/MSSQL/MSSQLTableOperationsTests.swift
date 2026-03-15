import XCTest
@testable import Echo

/// Tests SQL Server table DDL operations through Echo's DatabaseSession layer.
final class MSSQLTableOperationsTests: MSSQLDockerTestCase {

    // MARK: - Create Table

    func testCreateTable() async throws {
        let tableName = uniqueTableName()
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT IDENTITY(1,1) PRIMARY KEY,
                name NVARCHAR(100) NOT NULL,
                created_at DATETIME2 DEFAULT GETDATE()
            )
        """)
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let objects = try await session.listTablesAndViews(schema: "dbo")
        IntegrationTestHelpers.assertContainsObject(objects, name: tableName, type: .table)
    }

    func testCreateTableWithAllConstraints() async throws {
        let parentTable = uniqueTableName(prefix: "parent")
        let childTable = uniqueTableName(prefix: "child")

        try await execute("""
            CREATE TABLE dbo.[\(parentTable)] (
                id INT PRIMARY KEY,
                code NVARCHAR(10) UNIQUE NOT NULL
            )
        """)
        try await execute("""
            CREATE TABLE dbo.[\(childTable)] (
                id INT PRIMARY KEY,
                parent_id INT NOT NULL REFERENCES dbo.[\(parentTable)](id),
                value INT CHECK (value >= 0),
                status NVARCHAR(20) DEFAULT 'active'
            )
        """)
        cleanupSQL(
            "DROP TABLE dbo.[\(childTable)]",
            "DROP TABLE dbo.[\(parentTable)]"
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: childTable)
        XCTAssertEqual(details.columns.count, 4)
        XCTAssertNotNil(details.primaryKey)
        XCTAssertFalse(details.foreignKeys.isEmpty)
    }

    // MARK: - Rename Table

    func testRenameTable() async throws {
        let oldName = uniqueTableName(prefix: "old")
        let newName = uniqueTableName(prefix: "new")
        try await execute("CREATE TABLE dbo.[\(oldName)] (id INT PRIMARY KEY)")
        cleanupSQL(
            "DROP TABLE IF EXISTS dbo.[\(newName)]",
            "DROP TABLE IF EXISTS dbo.[\(oldName)]"
        )

        try await session.renameTable(schema: "dbo", oldName: oldName, newName: newName)

        let objects = try await session.listTablesAndViews(schema: "dbo")
        IntegrationTestHelpers.assertContainsObject(objects, name: newName)
        let oldExists = objects.contains { $0.name == oldName }
        XCTAssertFalse(oldExists, "Old table name should no longer exist")
    }

    // MARK: - Drop Table

    func testDropTable() async throws {
        let tableName = uniqueTableName()
        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT)")

        try await session.dropTable(schema: "dbo", name: tableName, ifExists: false)

        let objects = try await session.listTablesAndViews(schema: "dbo")
        let exists = objects.contains { $0.name.caseInsensitiveCompare(tableName) == .orderedSame }
        XCTAssertFalse(exists, "Table should be dropped")
    }

    func testDropTableIfExistsNonexistent() async throws {
        // Should not throw
        try await session.dropTable(schema: "dbo", name: "nonexistent_table_xyz_999", ifExists: true)
    }

    // MARK: - Truncate Table

    func testTruncateTable() async throws {
        let tableName = uniqueTableName()
        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT, name NVARCHAR(50))")
        try await execute("INSERT INTO dbo.[\(tableName)] VALUES (1, 'a'), (2, 'b'), (3, 'c')")
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        // Verify data exists
        let before = try await query("SELECT COUNT(*) AS cnt FROM dbo.[\(tableName)]")
        XCTAssertEqual(before.rows[0][0], "3")

        try await session.truncateTable(schema: "dbo", name: tableName)

        let after = try await query("SELECT COUNT(*) AS cnt FROM dbo.[\(tableName)]")
        XCTAssertEqual(after.rows[0][0], "0")
    }

    // MARK: - Table Operations with Data Integrity

    func testCreateInsertSelectDrop() async throws {
        let tableName = uniqueTableName()
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT PRIMARY KEY,
                name NVARCHAR(50) NOT NULL,
                score DECIMAL(5,2)
            )
        """)
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        try await execute("INSERT INTO dbo.[\(tableName)] VALUES (1, 'Alice', 95.5)")
        try await execute("INSERT INTO dbo.[\(tableName)] VALUES (2, 'Bob', 87.3)")

        let result = try await query("SELECT * FROM dbo.[\(tableName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertEqual(result.rows[0][1], "Alice")
        XCTAssertEqual(result.rows[1][1], "Bob")
    }
}

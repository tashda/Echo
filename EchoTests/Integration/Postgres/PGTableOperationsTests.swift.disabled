import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL table DDL operations through Echo's DatabaseSession layer.
final class PGTableOperationsTests: PostgresDockerTestCase {

    // MARK: - Create Table

    func testCreateTable() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name", nullable: false),
            PostgresColumnDefinition(name: "created_at", dataType: "TIMESTAMPTZ", defaultValue: "NOW()")
        ])
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        let objects = try await session.listTablesAndViews(schema: "public")
        IntegrationTestHelpers.assertContainsObject(objects, name: tableName, type: .table)
    }

    func testCreateTableWithAllConstraintTypes() async throws {
        let parentTable = uniqueName(prefix: "parent")
        let childTable = uniqueName(prefix: "child")

        try await postgresClient.admin.createTable(name: parentTable, columns: [
            .serial(name: "id", primaryKey: true),
            PostgresColumnDefinition(name: "code", dataType: "VARCHAR(10)", nullable: false, unique: true)
        ])
        // Child table has a foreign key and CHECK constraint — use raw SQL for those
        // since createTable doesn't support REFERENCES or CHECK constraints
        try await execute("""
            CREATE TABLE public.\(childTable) (
                id SERIAL PRIMARY KEY,
                parent_id INT NOT NULL REFERENCES public.\(parentTable)(id),
                value INT CHECK (value >= 0),
                status TEXT DEFAULT 'active'
            )
        """)
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(childTable)",
            "DROP TABLE IF EXISTS public.\(parentTable)"
        )

        let details = try await session.getTableStructureDetails(schema: "public", table: childTable)
        XCTAssertEqual(details.columns.count, 4)
        XCTAssertNotNil(details.primaryKey)
        XCTAssertFalse(details.foreignKeys.isEmpty)
    }

    // MARK: - Rename Table

    func testRenameTable() async throws {
        let oldName = uniqueName(prefix: "old")
        let newName = uniqueName(prefix: "new")
        try await postgresClient.admin.createTable(name: oldName, columns: [
            .serial(name: "id", primaryKey: true)
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(newName)",
            "DROP TABLE IF EXISTS public.\(oldName)"
        )

        try await session.renameTable(schema: "public", oldName: oldName, newName: newName)

        let objects = try await session.listTablesAndViews(schema: "public")
        IntegrationTestHelpers.assertContainsObject(objects, name: newName)
        let oldExists = objects.contains { $0.name == oldName }
        XCTAssertFalse(oldExists, "Old table name should no longer exist")
    }

    // MARK: - Drop Table

    func testDropTable() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .integer(name: "id")
        ])

        try await session.dropTable(schema: "public", name: tableName, ifExists: false)

        let objects = try await session.listTablesAndViews(schema: "public")
        let exists = objects.contains { $0.name.caseInsensitiveCompare(tableName) == .orderedSame }
        XCTAssertFalse(exists, "Table should be dropped")
    }

    func testDropTableIfExistsNonexistent() async throws {
        // Should not throw
        try await session.dropTable(schema: "public", name: "nonexistent_table_xyz_999", ifExists: true)
    }

    // MARK: - Truncate Table

    func testTruncateTable() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .integer(name: "id"),
            .text(name: "name")
        ])
        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["id", "name"],
            values: [[1, "a"], [2, "b"], [3, "c"]]
        )
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        // Verify data exists
        let before = try await query("SELECT COUNT(*) AS cnt FROM public.\(tableName)")
        XCTAssertEqual(before.rows[0][0], "3")

        try await session.truncateTable(schema: "public", name: tableName)

        let after = try await query("SELECT COUNT(*) AS cnt FROM public.\(tableName)")
        XCTAssertEqual(after.rows[0][0], "0")
    }

    // MARK: - Full Lifecycle

    func testCreateInsertSelectDrop() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name", nullable: false),
            PostgresColumnDefinition(name: "score", dataType: "NUMERIC(5,2)")
        ])
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["name", "score"],
            values: [["Alice", 95.5]]
        )
        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["name", "score"],
            values: [["Bob", 87.3]]
        )

        let result = try await query("SELECT name, score FROM public.\(tableName) ORDER BY name")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertEqual(result.rows[0][0], "Alice")
        XCTAssertEqual(result.rows[1][0], "Bob")
    }
}

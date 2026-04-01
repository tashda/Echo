import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL view operations through Echo's DatabaseSession layer.
final class PGViewTests: PostgresDockerTestCase {

    // MARK: - Create View

    func testCreateView() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name"),
            .boolean(name: "active", defaultValue: true)
        ])
        try await postgresClient.admin.createView(
            name: viewName,
            query: "SELECT id, name FROM \(tableName) WHERE active = TRUE"
        )
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let objects = try await session.listTablesAndViews(schema: "public")
        IntegrationTestHelpers.assertContainsObject(objects, name: viewName, type: .view)
    }

    func testQueryThroughView() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name"),
            .boolean(name: "active")
        ])
        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["name", "active"],
            values: [["Alice", true], ["Bob", false], ["Carol", true]]
        )
        try await postgresClient.admin.createView(
            name: viewName,
            query: "SELECT id, name FROM \(tableName) WHERE active = TRUE"
        )
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let result = try await query("SELECT * FROM public.\(viewName) ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertEqual(result.rows[0][1], "Alice")
        XCTAssertEqual(result.rows[1][1], "Carol")
    }

    // MARK: - Alter View

    func testAlterView() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name"),
            .text(name: "email")
        ])
        try await postgresClient.admin.createView(
            name: viewName,
            query: "SELECT id, name FROM \(tableName)"
        )
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        // PostgreSQL uses CREATE OR REPLACE VIEW to alter
        try await postgresClient.admin.createView(
            name: viewName,
            query: "SELECT id, name, email FROM \(tableName)",
            orReplace: true
        )

        let definition = try await session.getObjectDefinition(
            objectName: viewName, schemaName: "public", objectType: .view
        )
        XCTAssertTrue(definition.lowercased().contains("email"))
    }

    // MARK: - Drop View

    func testDropView() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true)
        ])
        try await postgresClient.admin.createView(
            name: viewName,
            query: "SELECT id FROM \(tableName)"
        )
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await postgresClient.admin.dropView(name: viewName)

        let objects = try await session.listTablesAndViews(schema: "public")
        let exists = objects.contains { $0.name.caseInsensitiveCompare(viewName) == .orderedSame }
        XCTAssertFalse(exists)
    }

    // MARK: - View Definition

    func testGetViewDefinition() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name")
        ])
        try await postgresClient.admin.createView(
            name: viewName,
            query: "SELECT id, name FROM \(tableName) WHERE id > 0"
        )
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let definition = try await session.getObjectDefinition(
            objectName: viewName, schemaName: "public", objectType: .view
        )
        XCTAssertFalse(definition.isEmpty)
        XCTAssertTrue(definition.lowercased().contains("select"))
    }

    // MARK: - View with Joins

    func testViewWithJoin() async throws {
        let t1 = uniqueName(prefix: "dept")
        let t2 = uniqueName(prefix: "emp")
        let viewName = uniqueName(prefix: "v")
        try await postgresClient.admin.createTable(name: t1, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name")
        ])
        try await postgresClient.admin.createTable(name: t2, columns: [
            .serial(name: "id", primaryKey: true),
            .integer(name: "dept_id"),
            .text(name: "name")
        ])
        try await postgresClient.connection.insert(into: t1, columns: ["id", "name"], values: [[1, "Engineering"]])
        try await postgresClient.connection.insert(into: t2, columns: ["dept_id", "name"], values: [[1, "Alice"], [1, "Bob"]])
        try await postgresClient.admin.createView(
            name: viewName,
            query: """
                SELECT e.name AS employee, d.name AS department
                FROM \(t2) e JOIN \(t1) d ON e.dept_id = d.id
            """
        )
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(t2)",
            "DROP TABLE IF EXISTS public.\(t1)"
        )

        let result = try await query("SELECT * FROM public.\(viewName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    // MARK: - Materialized View

    func testCreateMaterializedView() async throws {
        let tableName = uniqueName()
        let matViewName = uniqueName(prefix: "mv")
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "category"),
            PostgresColumnDefinition(name: "amount", dataType: "NUMERIC")
        ])
        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["category", "amount"],
            values: [["A", 100], ["A", 200], ["B", 50]]
        )
        try await postgresClient.admin.createMaterializedView(
            name: matViewName,
            query: "SELECT category, SUM(amount) AS total FROM \(tableName) GROUP BY category"
        )
        cleanupSQL(
            "DROP MATERIALIZED VIEW IF EXISTS public.\(matViewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let result = try await query("SELECT * FROM public.\(matViewName) ORDER BY category")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    func testRefreshMaterializedView() async throws {
        let tableName = uniqueName()
        let matViewName = uniqueName(prefix: "mv")
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .integer(name: "value")
        ])
        try await postgresClient.connection.insert(into: tableName, columns: ["value"], values: [[1], [2]])
        try await postgresClient.admin.createMaterializedView(
            name: matViewName,
            query: "SELECT COUNT(*) AS cnt FROM \(tableName)"
        )
        cleanupSQL(
            "DROP MATERIALIZED VIEW IF EXISTS public.\(matViewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        // Verify initial count
        let before = try await query("SELECT cnt FROM public.\(matViewName)")
        XCTAssertEqual(before.rows[0][0], "2")

        // Insert more data and refresh
        try await postgresClient.connection.insert(into: tableName, columns: ["value"], values: [[3], [4], [5]])
        try await postgresClient.admin.refreshMaterializedView(name: matViewName)

        let after = try await query("SELECT cnt FROM public.\(matViewName)")
        XCTAssertEqual(after.rows[0][0], "5")
    }
}

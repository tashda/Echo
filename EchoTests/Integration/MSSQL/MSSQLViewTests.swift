import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server view operations through Echo's DatabaseSession layer.
final class MSSQLViewTests: MSSQLDockerTestCase {

    // MARK: - Create View

    func testCreateView() async throws {
        let tableName = uniqueTableName()
        let viewName = uniqueTableName(prefix: "v")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "active", definition: .standard(.init(dataType: .bit, defaultValue: "1"))),
        ])
        try await sqlserverClient.views.createView(
            name: viewName,
            query: "SELECT id, name FROM [\(tableName)] WHERE active = 1"
        )
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
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "active", definition: .standard(.init(dataType: .bit))),
        ])
        try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "name", "active"],
            values: [
                [.int(1), .nString("Alice"), .bool(true)],
                [.int(2), .nString("Bob"), .bool(false)],
                [.int(3), .nString("Carol"), .bool(true)],
            ]
        )
        try await sqlserverClient.views.createView(
            name: viewName,
            query: "SELECT id, name FROM [\(tableName)] WHERE active = 1"
        )
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
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "email", definition: .standard(.init(dataType: .nvarchar(length: .length(200))))),
        ])
        try await sqlserverClient.views.createView(
            name: viewName,
            query: "SELECT id, name FROM [\(tableName)]"
        )
        cleanupSQL(
            "DROP VIEW [\(viewName)]",
            "DROP TABLE [\(tableName)]"
        )

        // Alter to include email — no typed API for ALTER VIEW, use raw SQL
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
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        try await sqlserverClient.views.createView(
            name: viewName,
            query: "SELECT id FROM [\(tableName)]"
        )
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.views.dropView(name: viewName)

        let objects = try await session.listTablesAndViews(schema: "dbo")
        let exists = objects.contains { $0.name.caseInsensitiveCompare(viewName) == .orderedSame }
        XCTAssertFalse(exists)
    }

    // MARK: - View Definition

    func testGetViewDefinition() async throws {
        let tableName = uniqueTableName()
        let viewName = uniqueTableName(prefix: "v")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.views.createView(
            name: viewName,
            query: "SELECT id, name FROM [\(tableName)] WHERE id > 0"
        )
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
        try await sqlserverClient.admin.createTable(name: t1, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.admin.createTable(name: t2, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "dept_id", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.admin.insertRow(
            into: t1,
            values: ["id": .int(1), "name": .nString("Engineering")]
        )
        try await sqlserverClient.admin.insertRows(
            into: t2,
            columns: ["id", "dept_id", "name"],
            values: [
                [.int(1), .int(1), .nString("Alice")],
                [.int(2), .int(1), .nString("Bob")],
            ]
        )
        try await sqlserverClient.views.createView(
            name: viewName,
            query: """
                SELECT e.name AS employee, d.name AS department
                FROM [\(t2)] e JOIN [\(t1)] d ON e.dept_id = d.id
            """
        )
        cleanupSQL(
            "DROP VIEW [\(viewName)]",
            "DROP TABLE [\(t2)]",
            "DROP TABLE [\(t1)]"
        )

        let result = try await query("SELECT * FROM [\(viewName)]")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }
}

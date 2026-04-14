import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server table DDL operations through Echo's DatabaseSession layer.
final class MSSQLTableOperationsTests: MSSQLDockerTestCase {

    // MARK: - Create Table

    func testCreateTable() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true, identity: (seed: 1, increment: 1)))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "created_at", definition: .standard(.init(dataType: .datetime2(precision: 7), defaultValue: "GETDATE()"))),
        ])
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let objects = try await session.listTablesAndViews(schema: "dbo")
        IntegrationTestHelpers.assertContainsObject(objects, name: tableName, type: .table)
    }

    func testCreateTableWithAllConstraints() async throws {
        let parentTable = uniqueTableName(prefix: "parent")
        let childTable = uniqueTableName(prefix: "child")

        try await sqlserverClient.admin.createTable(name: parentTable, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "code", definition: .standard(.init(dataType: .nvarchar(length: .length(10)), isUnique: true))),
        ])
        try await sqlserverClient.admin.createTable(name: childTable, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "parent_id", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "status", definition: .standard(.init(dataType: .nvarchar(length: .length(20)), defaultValue: "N'active'"))),
        ])
        try await sqlserverClient.constraints.addForeignKey(
            name: "FK_\(childTable)_parent",
            table: childTable,
            columns: ["parent_id"],
            referencedTable: parentTable,
            referencedColumns: ["id"]
        )
        try await sqlserverClient.constraints.addCheckConstraint(
            name: "CK_\(childTable)_value",
            table: childTable,
            expression: "[value] >= 0"
        )
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
        try await sqlserverClient.admin.createTable(name: oldName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        cleanupSQL(
            "DROP TABLE dbo.[\(newName)]",
            "DROP TABLE dbo.[\(oldName)]"
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
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int))),
        ])

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
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(50))))),
        ])
        try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "name"],
            values: [
                [.int(1), .nString("a")],
                [.int(2), .nString("b")],
                [.int(3), .nString("c")],
            ]
        )
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
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(50))))),
            SQLServerColumnDefinition(name: "score", definition: .standard(.init(dataType: .decimal(precision: 5, scale: 2)))),
        ])
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "name": .nString("Alice"), "score": .decimal("95.5")]
        )
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(2), "name": .nString("Bob"), "score": .decimal("87.3")]
        )

        let result = try await query("SELECT * FROM dbo.[\(tableName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertEqual(result.rows[0][1], "Alice")
        XCTAssertEqual(result.rows[1][1], "Bob")
    }
}

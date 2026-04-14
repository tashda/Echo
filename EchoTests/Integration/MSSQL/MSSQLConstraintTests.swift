import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server constraint operations through Echo's DatabaseSession layer.
final class MSSQLConstraintTests: MSSQLDockerTestCase {

    // MARK: - Primary Key

    func testCreateTableWithPrimaryKey() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertNotNil(details.primaryKey)
        XCTAssertTrue(details.primaryKey?.columns.contains("id") ?? false)
    }

    func testCompositePrimaryKey() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "a", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "b", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.constraints.addPrimaryKey(
            name: "PK_\(tableName)_ab",
            table: tableName,
            columns: ["a", "b"]
        )
        cleanupSQL("DROP TABLE [\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertNotNil(details.primaryKey)
        XCTAssertEqual(details.primaryKey?.columns.count, 2)
    }

    func testAddPrimaryKeyConstraint() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.constraints.addPrimaryKey(
            name: "PK_\(tableName)",
            table: tableName,
            columns: ["id"]
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertNotNil(details.primaryKey)
    }

    // MARK: - Foreign Key

    func testForeignKeyConstraint() async throws {
        let parent = uniqueTableName(prefix: "fk_parent")
        let child = uniqueTableName(prefix: "fk_child")
        try await sqlserverClient.admin.createTable(name: parent, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        try await sqlserverClient.admin.createTable(name: child, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "parent_id", definition: .standard(.init(dataType: .int))),
        ])
        try await sqlserverClient.constraints.addForeignKey(
            name: "FK_\(child)_parent",
            table: child,
            columns: ["parent_id"],
            referencedTable: parent,
            referencedColumns: ["id"]
        )
        cleanupSQL(
            "DROP TABLE [\(child)]",
            "DROP TABLE [\(parent)]"
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: child)
        XCTAssertFalse(details.foreignKeys.isEmpty, "Should detect FK constraint")

        let fk = details.foreignKeys.first
        XCTAssertTrue(fk?.columns.contains("parent_id") ?? false)
    }

    func testForeignKeyWithCascade() async throws {
        let parent = uniqueTableName(prefix: "cas_parent")
        let child = uniqueTableName(prefix: "cas_child")
        try await sqlserverClient.admin.createTable(name: parent, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        try await sqlserverClient.admin.createTable(name: child, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "parent_id", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL(
            "DROP TABLE [\(child)]",
            "DROP TABLE [\(parent)]"
        )

        // Cascade options require raw SQL — no typed API for ON DELETE/UPDATE CASCADE
        try await execute("""
            ALTER TABLE [\(child)] ADD CONSTRAINT FK_\(child)_cascade
            FOREIGN KEY (parent_id) REFERENCES [\(parent)](id) ON DELETE CASCADE ON UPDATE CASCADE
        """)

        let details = try await session.getTableStructureDetails(schema: "dbo", table: child)
        XCTAssertFalse(details.foreignKeys.isEmpty)
    }

    // MARK: - Unique Constraint

    func testUniqueConstraint() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "code", definition: .standard(.init(dataType: .nvarchar(length: .length(10))))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.constraints.addUniqueConstraint(
            name: "UQ_\(tableName)_code",
            table: tableName,
            columns: ["code"]
        )
        cleanupSQL("DROP TABLE [\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let hasUnique = !details.uniqueConstraints.isEmpty ||
            details.indexes.contains(where: { $0.isUnique && $0.columns.contains(where: { $0.name.caseInsensitiveCompare("code") == .orderedSame }) })
        XCTAssertTrue(hasUnique, "Should detect unique constraint on 'code'")
    }

    func testAddUniqueConstraint() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "email", definition: .standard(.init(dataType: .nvarchar(length: .length(200))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.constraints.addUniqueConstraint(
            name: "UQ_\(tableName)_email",
            table: tableName,
            columns: ["email"]
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let hasUnique = !details.uniqueConstraints.isEmpty ||
            details.indexes.contains(where: { $0.isUnique })
        XCTAssertTrue(hasUnique)
    }

    // MARK: - Check Constraint

    func testCheckConstraint() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "age", definition: .standard(.init(dataType: .int))),
        ])
        try await sqlserverClient.constraints.addCheckConstraint(
            name: "CK_\(tableName)_age",
            table: tableName,
            expression: "[age] >= 0 AND [age] <= 150"
        )
        cleanupSQL("DROP TABLE [\(tableName)]")

        // Insert valid data
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "age": .int(25)]
        )
        let result = try await query("SELECT age FROM [\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "25")

        // Insert invalid data should fail
        do {
            try await sqlserverClient.admin.insertRow(
                into: tableName,
                values: ["id": .int(2), "age": .int(-5)]
            )
            XCTFail("Should reject negative age")
        } catch {
            // Expected
        }
    }

    // MARK: - Default Constraint

    func testDefaultConstraint() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "status", definition: .standard(.init(dataType: .nvarchar(length: .length(20))))),
            SQLServerColumnDefinition(name: "created_at", definition: .standard(.init(dataType: .datetime2(precision: 7), defaultValue: "GETDATE()"))),
        ])
        try await sqlserverClient.constraints.addDefaultConstraint(
            name: "DF_\(tableName)_status",
            table: tableName,
            column: "status",
            defaultValue: "N'active'"
        )
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1)]
        )
        let result = try await query("SELECT status FROM [\(tableName)] WHERE id = 1")
        XCTAssertEqual(result.rows[0][0], "active")
    }

    // MARK: - Drop Constraints

    func testDropForeignKey() async throws {
        let parent = uniqueTableName(prefix: "dp")
        let child = uniqueTableName(prefix: "dc")
        let fkName = "FK_\(child)_parent"
        try await sqlserverClient.admin.createTable(name: parent, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        try await sqlserverClient.admin.createTable(name: child, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "parent_id", definition: .standard(.init(dataType: .int))),
        ])
        try await sqlserverClient.constraints.addForeignKey(
            name: fkName,
            table: child,
            columns: ["parent_id"],
            referencedTable: parent,
            referencedColumns: ["id"]
        )
        cleanupSQL(
            "DROP TABLE [\(child)]",
            "DROP TABLE [\(parent)]"
        )

        try await sqlserverClient.constraints.dropForeignKey(name: fkName, table: child)

        let details = try await session.getTableStructureDetails(schema: "dbo", table: child)
        XCTAssertTrue(details.foreignKeys.isEmpty, "FK should be dropped")
    }
}

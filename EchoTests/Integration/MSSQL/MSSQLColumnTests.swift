import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server column operations through Echo's DatabaseSession layer.
final class MSSQLColumnTests: MSSQLDockerTestCase {

    // MARK: - Add Column

    func testAddColumn() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.addColumn(
            table: tableName,
            name: "email",
            dataType: "NVARCHAR(200)"
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "email")
    }

    func testAddColumnWithDefault() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.addColumn(
            table: tableName,
            name: "status",
            dataType: "NVARCHAR(20)",
            defaultValue: "N'active'"
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "status")
    }

    func testAddColumnNotNull() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.addColumn(
            table: tableName,
            name: "name",
            dataType: "NVARCHAR(100)",
            isNullable: false,
            defaultValue: "N''"
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let nameCol = details.columns.first { $0.name.caseInsensitiveCompare("name") == .orderedSame }
        XCTAssertNotNil(nameCol)
        XCTAssertEqual(nameCol?.isNullable, false)
    }

    // MARK: - Modify Column

    func testAlterColumnType() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(50))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.alterColumnType(
            table: tableName,
            column: "name",
            newType: "NVARCHAR(200)",
            isNullable: true
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let nameCol = details.columns.first { $0.name.caseInsensitiveCompare("name") == .orderedSame }
        XCTAssertNotNil(nameCol)
        // Data type should reflect the new size
        XCTAssertTrue(nameCol?.dataType.lowercased().contains("nvarchar") ?? false)
    }

    func testAlterColumnNullability() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.alterColumnType(
            table: tableName,
            column: "value",
            newType: "INT",
            isNullable: true
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let valueCol = details.columns.first { $0.name.caseInsensitiveCompare("value") == .orderedSame }
        XCTAssertEqual(valueCol?.isNullable, true)
    }

    // MARK: - Drop Column

    func testDropColumn() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "temp_col", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.dropColumn(table: tableName, column: "temp_col")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let hasTempCol = details.columns.contains { $0.name.caseInsensitiveCompare("temp_col") == .orderedSame }
        XCTAssertFalse(hasTempCol, "Dropped column should not appear")
    }

    // MARK: - Rename Column

    func testRenameColumn() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "old_name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.renameColumn(table: tableName, from: "old_name", to: "new_name")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "new_name")
        let hasOld = details.columns.contains { $0.name.caseInsensitiveCompare("old_name") == .orderedSame }
        XCTAssertFalse(hasOld)
    }

    // MARK: - Multiple Column Operations

    func testAddMultipleColumns() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.addColumn(
            table: tableName, name: "first_name", dataType: "NVARCHAR(50)"
        )
        try await sqlserverClient.admin.addColumn(
            table: tableName, name: "last_name", dataType: "NVARCHAR(50)"
        )
        try await sqlserverClient.admin.addColumn(
            table: tableName, name: "age", dataType: "INT"
        )
        try await sqlserverClient.admin.addColumn(
            table: tableName, name: "salary", dataType: "DECIMAL(10,2)"
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertEqual(details.columns.count, 5)
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "first_name")
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "salary")
    }
}

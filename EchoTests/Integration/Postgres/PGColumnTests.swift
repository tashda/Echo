import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL column operations through Echo's DatabaseSession layer.
final class PGColumnTests: PostgresDockerTestCase {

    // MARK: - Add Column

    func testAddColumn() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY") { tableName in
            try await postgresClient.admin.addColumn(
                table: tableName,
                column: .text(name: "email")
            )

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "email")
        }
    }

    func testAddColumnWithDefault() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY") { tableName in
            try await postgresClient.admin.addColumn(
                table: tableName,
                column: .text(name: "status", defaultValue: "'active'")
            )

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "status")

            // Insert a row without specifying status to verify default
            try await execute("INSERT INTO public.\(tableName) DEFAULT VALUES")
            let result = try await query("SELECT status FROM public.\(tableName)")
            XCTAssertEqual(result.rows[0][0], "active")
        }
    }

    func testAddColumnNotNull() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY") { tableName in
            try await postgresClient.admin.addColumn(
                table: tableName,
                column: PostgresColumnDefinition(name: "name", dataType: "TEXT", nullable: false, defaultValue: "''")
            )

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            let nameCol = details.columns.first { $0.name.caseInsensitiveCompare("name") == .orderedSame }
            XCTAssertNotNil(nameCol)
            XCTAssertEqual(nameCol?.isNullable, false)
        }
    }

    // MARK: - Alter Column

    func testAlterColumnType() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name VARCHAR(50)") { tableName in
            try await postgresClient.admin.alterColumnType(table: tableName, column: "name", newType: "VARCHAR(200)")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            let nameCol = details.columns.first { $0.name.caseInsensitiveCompare("name") == .orderedSame }
            XCTAssertNotNil(nameCol)
            XCTAssertTrue(nameCol?.dataType.lowercased().contains("character varying") ?? false)
        }
    }

    func testAlterColumnNullability() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, value INT NOT NULL") { tableName in
            try await postgresClient.admin.alterColumnNullability(table: tableName, column: "value", nullable: true)

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            let valueCol = details.columns.first { $0.name.caseInsensitiveCompare("value") == .orderedSame }
            XCTAssertEqual(valueCol?.isNullable, true)
        }
    }

    // MARK: - Drop Column

    func testDropColumn() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, temp_col INT") { tableName in
            try await postgresClient.admin.dropColumn(table: tableName, column: "temp_col")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            let hasTempCol = details.columns.contains { $0.name.caseInsensitiveCompare("temp_col") == .orderedSame }
            XCTAssertFalse(hasTempCol, "Dropped column should not appear")
        }
    }

    // MARK: - Rename Column

    func testRenameColumn() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, old_name TEXT") { tableName in
            try await postgresClient.admin.renameColumn(table: tableName, oldName: "old_name", newName: "new_name")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "new_name")
            let hasOld = details.columns.contains { $0.name.caseInsensitiveCompare("old_name") == .orderedSame }
            XCTAssertFalse(hasOld)
        }
    }

    // MARK: - Multiple Columns

    func testAddMultipleColumns() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY") { tableName in
            try await postgresClient.admin.addColumn(table: tableName, column: .text(name: "first_name"))
            try await postgresClient.admin.addColumn(table: tableName, column: .text(name: "last_name"))
            try await postgresClient.admin.addColumn(table: tableName, column: .integer(name: "age"))
            try await postgresClient.admin.addColumn(
                table: tableName,
                column: PostgresColumnDefinition(name: "salary", dataType: "NUMERIC(10,2)")
            )

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            XCTAssertEqual(details.columns.count, 5)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "first_name")
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "salary")
        }
    }
}

import XCTest
@testable import Echo

/// Tests SQL Server column operations through Echo's DatabaseSession layer.
final class MSSQLColumnTests: MSSQLDockerTestCase {

    // MARK: - Add Column

    func testAddColumn() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY") { tableName in
            try await execute("ALTER TABLE [\(tableName)] ADD email NVARCHAR(200)")

            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "email")
        }
    }

    func testAddColumnWithDefault() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY") { tableName in
            try await execute("ALTER TABLE [\(tableName)] ADD status NVARCHAR(20) DEFAULT 'active'")

            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "status")
        }
    }

    func testAddColumnNotNull() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY") { tableName in
            try await execute("ALTER TABLE [\(tableName)] ADD name NVARCHAR(100) NOT NULL DEFAULT ''")

            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            let nameCol = details.columns.first { $0.name.caseInsensitiveCompare("name") == .orderedSame }
            XCTAssertNotNil(nameCol)
            XCTAssertEqual(nameCol?.isNullable, false)
        }
    }

    // MARK: - Modify Column

    func testAlterColumnType() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name NVARCHAR(50)") { tableName in
            try await execute("ALTER TABLE [\(tableName)] ALTER COLUMN name NVARCHAR(200)")

            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            let nameCol = details.columns.first { $0.name.caseInsensitiveCompare("name") == .orderedSame }
            XCTAssertNotNil(nameCol)
            // Data type should reflect the new size
            XCTAssertTrue(nameCol?.dataType.lowercased().contains("nvarchar") ?? false)
        }
    }

    func testAlterColumnNullability() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, value INT NOT NULL") { tableName in
            try await execute("ALTER TABLE [\(tableName)] ALTER COLUMN value INT NULL")

            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            let valueCol = details.columns.first { $0.name.caseInsensitiveCompare("value") == .orderedSame }
            XCTAssertEqual(valueCol?.isNullable, true)
        }
    }

    // MARK: - Drop Column

    func testDropColumn() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name NVARCHAR(100), temp_col INT") { tableName in
            try await execute("ALTER TABLE [\(tableName)] DROP COLUMN temp_col")

            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            let hasTempCol = details.columns.contains { $0.name.caseInsensitiveCompare("temp_col") == .orderedSame }
            XCTAssertFalse(hasTempCol, "Dropped column should not appear")
        }
    }

    // MARK: - Rename Column

    func testRenameColumn() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, old_name NVARCHAR(100)") { tableName in
            try await execute("EXEC sp_rename '[\(tableName)].old_name', 'new_name', 'COLUMN'")

            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "new_name")
            let hasOld = details.columns.contains { $0.name.caseInsensitiveCompare("old_name") == .orderedSame }
            XCTAssertFalse(hasOld)
        }
    }

    // MARK: - Multiple Column Operations

    func testAddMultipleColumns() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY") { tableName in
            try await execute("""
                ALTER TABLE [\(tableName)] ADD
                    first_name NVARCHAR(50),
                    last_name NVARCHAR(50),
                    age INT,
                    salary DECIMAL(10,2)
            """)

            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            XCTAssertEqual(details.columns.count, 5)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "first_name")
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "salary")
        }
    }
}

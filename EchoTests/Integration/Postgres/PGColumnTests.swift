import XCTest
@testable import Echo

/// Tests PostgreSQL column operations through Echo's DatabaseSession layer.
final class PGColumnTests: PostgresDockerTestCase {

    // MARK: - Add Column

    func testAddColumn() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY") { tableName in
            try await execute("ALTER TABLE public.\(tableName) ADD COLUMN email TEXT")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "email")
        }
    }

    func testAddColumnWithDefault() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY") { tableName in
            try await execute("ALTER TABLE public.\(tableName) ADD COLUMN status TEXT DEFAULT 'active'")

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
            try await execute("ALTER TABLE public.\(tableName) ADD COLUMN name TEXT NOT NULL DEFAULT ''")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            let nameCol = details.columns.first { $0.name.caseInsensitiveCompare("name") == .orderedSame }
            XCTAssertNotNil(nameCol)
            XCTAssertEqual(nameCol?.isNullable, false)
        }
    }

    // MARK: - Alter Column

    func testAlterColumnType() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name VARCHAR(50)") { tableName in
            try await execute("ALTER TABLE public.\(tableName) ALTER COLUMN name TYPE VARCHAR(200)")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            let nameCol = details.columns.first { $0.name.caseInsensitiveCompare("name") == .orderedSame }
            XCTAssertNotNil(nameCol)
            XCTAssertTrue(nameCol?.dataType.lowercased().contains("character varying") ?? false)
        }
    }

    func testAlterColumnNullability() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, value INT NOT NULL") { tableName in
            try await execute("ALTER TABLE public.\(tableName) ALTER COLUMN value DROP NOT NULL")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            let valueCol = details.columns.first { $0.name.caseInsensitiveCompare("value") == .orderedSame }
            XCTAssertEqual(valueCol?.isNullable, true)
        }
    }

    // MARK: - Drop Column

    func testDropColumn() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT, temp_col INT") { tableName in
            try await execute("ALTER TABLE public.\(tableName) DROP COLUMN temp_col")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            let hasTempCol = details.columns.contains { $0.name.caseInsensitiveCompare("temp_col") == .orderedSame }
            XCTAssertFalse(hasTempCol, "Dropped column should not appear")
        }
    }

    // MARK: - Rename Column

    func testRenameColumn() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, old_name TEXT") { tableName in
            try await execute("ALTER TABLE public.\(tableName) RENAME COLUMN old_name TO new_name")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "new_name")
            let hasOld = details.columns.contains { $0.name.caseInsensitiveCompare("old_name") == .orderedSame }
            XCTAssertFalse(hasOld)
        }
    }

    // MARK: - Multiple Columns

    func testAddMultipleColumns() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY") { tableName in
            try await execute("ALTER TABLE public.\(tableName) ADD COLUMN first_name TEXT")
            try await execute("ALTER TABLE public.\(tableName) ADD COLUMN last_name TEXT")
            try await execute("ALTER TABLE public.\(tableName) ADD COLUMN age INT")
            try await execute("ALTER TABLE public.\(tableName) ADD COLUMN salary NUMERIC(10,2)")

            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            XCTAssertEqual(details.columns.count, 5)
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "first_name")
            IntegrationTestHelpers.assertHasStructureColumn(details, named: "salary")
        }
    }
}

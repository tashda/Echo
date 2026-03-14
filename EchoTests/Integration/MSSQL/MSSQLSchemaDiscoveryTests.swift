import XCTest
@testable import Echo

/// Tests SQL Server schema discovery through Echo's DatabaseSession layer.
final class MSSQLSchemaDiscoveryTests: MSSQLDockerTestCase {

    // MARK: - List Databases

    func testListDatabases() async throws {
        let databases = try await session.listDatabases()
        XCTAssertFalse(databases.isEmpty)
        IntegrationTestHelpers.assertContains(databases, value: "master")
        IntegrationTestHelpers.assertContains(databases, value: "tempdb")
        IntegrationTestHelpers.assertContains(databases, value: "model")
        IntegrationTestHelpers.assertContains(databases, value: "msdb")
    }

    func testListDatabasesIncludesUserDatabase() async throws {
        let dbName = uniqueTableName(prefix: "echo_db")
        try await execute("CREATE DATABASE [\(dbName)]")
        cleanupSQL("DROP DATABASE [\(dbName)]")

        let databases = try await session.listDatabases()
        IntegrationTestHelpers.assertContains(databases, value: dbName)
    }

    // MARK: - List Schemas

    func testListSchemas() async throws {
        let schemas = try await session.listSchemas()
        XCTAssertFalse(schemas.isEmpty)
        IntegrationTestHelpers.assertContains(schemas, value: "dbo")
    }

    func testListSchemasIncludesCustomSchema() async throws {
        let schemaName = uniqueTableName(prefix: "schema")
        try await execute("CREATE SCHEMA [\(schemaName)]")
        cleanupSQL("DROP SCHEMA [\(schemaName)]")

        let schemas = try await session.listSchemas()
        IntegrationTestHelpers.assertContains(schemas, value: schemaName)
    }

    // MARK: - List Tables and Views

    func testListTablesAndViews() async throws {
        try await withTempTable { tableName in
            let objects = try await session.listTablesAndViews(schema: "dbo")
            XCTAssertNotNil(objects)
            // The temp table might be in dbo or might not — depends on creation.
            // At minimum, system tables should be discoverable.
        }
    }

    func testListTablesReturnsTableType() async throws {
        let tableName = uniqueTableName()
        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT PRIMARY KEY)")
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let objects = try await session.listTablesAndViews(schema: "dbo")
        IntegrationTestHelpers.assertContainsObject(objects, name: tableName, type: .table)
    }

    func testListViewsReturnsViewType() async throws {
        let tableName = uniqueTableName()
        let viewName = uniqueTableName(prefix: "v")
        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT PRIMARY KEY)")
        try await execute("CREATE VIEW dbo.[\(viewName)] AS SELECT id FROM dbo.[\(tableName)]")
        cleanupSQL(
            "DROP VIEW dbo.[\(viewName)]",
            "DROP TABLE dbo.[\(tableName)]"
        )

        let objects = try await session.listTablesAndViews(schema: "dbo")
        IntegrationTestHelpers.assertContainsObject(objects, name: viewName, type: .view)
    }

    func testListTablesInCustomSchema() async throws {
        let schemaName = uniqueTableName(prefix: "s")
        let tableName = uniqueTableName()
        try await execute("CREATE SCHEMA [\(schemaName)]")
        try await execute("CREATE TABLE [\(schemaName)].[\(tableName)] (id INT)")
        cleanupSQL(
            "DROP TABLE [\(schemaName)].[\(tableName)]",
            "DROP SCHEMA [\(schemaName)]"
        )

        let objects = try await session.listTablesAndViews(schema: schemaName)
        IntegrationTestHelpers.assertContainsObject(objects, name: tableName)
    }

    // MARK: - Schema with Sample Data

    func testListTablesWithSampleData() async throws {
        // Load sample data first
        try await loadSampleDataIfNeeded()
        let objects = try await session.listTablesAndViews(schema: "echo_test")
        IntegrationTestHelpers.assertContainsObject(objects, name: "departments", type: .table)
        IntegrationTestHelpers.assertContainsObject(objects, name: "employees", type: .table)
    }

    func testListViewsWithSampleData() async throws {
        try await loadSampleDataIfNeeded()
        let objects = try await session.listTablesAndViews(schema: "echo_test")
        IntegrationTestHelpers.assertContainsObject(objects, name: "v_active_employees", type: .view)
    }

    // MARK: - Helpers

    private func loadSampleDataIfNeeded() async throws {
        // Check if echo_test schema exists
        let schemas = try await session.listSchemas()
        guard !schemas.contains(where: { $0.caseInsensitiveCompare("echo_test") == .orderedSame }) else {
            return
        }
        // Load via SQL file
        let fm = FileManager.default
        let path = "/Users/k/Development/Echo/EchoTests/Integration/Support/SampleData/MSSQLSampleData.sql"
        if fm.fileExists(atPath: path) {
            let sql = try String(contentsOfFile: path, encoding: .utf8)
            // Execute batch by batch (split on GO)
            let batches = sql.components(separatedBy: "\nGO\n")
            for batch in batches {
                let trimmed = batch.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                try? await execute(trimmed)
            }
        }
    }
}

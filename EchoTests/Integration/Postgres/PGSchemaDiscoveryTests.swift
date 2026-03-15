import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL schema discovery through Echo's DatabaseSession layer.
final class PGSchemaDiscoveryTests: PostgresDockerTestCase {

    // MARK: - List Databases

    func testListDatabases() async throws {
        let databases = try await session.listDatabases()
        XCTAssertFalse(databases.isEmpty)
        IntegrationTestHelpers.assertContains(databases, value: "postgres")
    }

    func testListDatabasesIncludesUserDatabase() async throws {
        let dbName = uniqueName(prefix: "echo_db")
        try await postgresClient.admin.createDatabase(name: dbName)
        cleanupSQL("DROP DATABASE IF EXISTS \(dbName)")

        let databases = try await session.listDatabases()
        IntegrationTestHelpers.assertContains(databases, value: dbName)
    }

    func testListDatabasesIncludesTemplate1() async throws {
        let databases = try await session.listDatabases()
        IntegrationTestHelpers.assertContains(databases, value: "template1")
    }

    // MARK: - List Schemas

    func testListSchemas() async throws {
        let schemas = try await session.listSchemas()
        XCTAssertFalse(schemas.isEmpty)
        IntegrationTestHelpers.assertContains(schemas, value: "public")
    }

    func testListSchemasIncludesCustomSchema() async throws {
        let schemaName = uniqueName(prefix: "schema")
        try await postgresClient.admin.createSchema(name: schemaName)
        cleanupSQL("DROP SCHEMA IF EXISTS \(schemaName) CASCADE")

        let schemas = try await session.listSchemas()
        IntegrationTestHelpers.assertContains(schemas, value: schemaName)
    }

    func testListSchemasIncludesInformationSchema() async throws {
        let schemas = try await session.listSchemas()
        IntegrationTestHelpers.assertContains(schemas, value: "information_schema")
    }

    // MARK: - List Tables and Views

    func testListTablesAndViews() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name")
        ])
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        let objects = try await session.listTablesAndViews(schema: "public")
        XCTAssertFalse(objects.isEmpty)
        IntegrationTestHelpers.assertContainsObject(objects, name: tableName)
    }

    func testListTablesReturnsTableType() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true)
        ])
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        let objects = try await session.listTablesAndViews(schema: "public")
        IntegrationTestHelpers.assertContainsObject(objects, name: tableName, type: .table)
    }

    func testListViewsReturnsViewType() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true)
        ])
        try await postgresClient.admin.createView(
            name: viewName,
            query: "SELECT id FROM \(tableName)"
        )
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let objects = try await session.listTablesAndViews(schema: "public")
        IntegrationTestHelpers.assertContainsObject(objects, name: viewName, type: .view)
    }

    func testListTablesInCustomSchema() async throws {
        let schemaName = uniqueName(prefix: "s")
        let tableName = uniqueName()
        try await postgresClient.admin.createSchema(name: schemaName)
        try await execute("CREATE TABLE \(schemaName).\(tableName) (id SERIAL PRIMARY KEY)")
        cleanupSQL(
            "DROP TABLE IF EXISTS \(schemaName).\(tableName)",
            "DROP SCHEMA IF EXISTS \(schemaName) CASCADE"
        )

        let objects = try await session.listTablesAndViews(schema: schemaName)
        IntegrationTestHelpers.assertContainsObject(objects, name: tableName)
    }

    func testListTablesExcludesOtherSchemas() async throws {
        let schema1 = uniqueName(prefix: "s1")
        let schema2 = uniqueName(prefix: "s2")
        let table1 = uniqueName(prefix: "t1")
        let table2 = uniqueName(prefix: "t2")
        try await postgresClient.admin.createSchema(name: schema1)
        try await postgresClient.admin.createSchema(name: schema2)
        try await execute("CREATE TABLE \(schema1).\(table1) (id INT)")
        try await execute("CREATE TABLE \(schema2).\(table2) (id INT)")
        cleanupSQL(
            "DROP SCHEMA IF EXISTS \(schema1) CASCADE",
            "DROP SCHEMA IF EXISTS \(schema2) CASCADE"
        )

        let objects = try await session.listTablesAndViews(schema: schema1)
        IntegrationTestHelpers.assertContainsObject(objects, name: table1)
        // table2 should not appear in schema1
        let hasTable2 = objects.contains { $0.name.caseInsensitiveCompare(table2) == .orderedSame }
        XCTAssertFalse(hasTable2, "Table from schema2 should not appear in schema1 listing")
    }

    // MARK: - Sample Data Schema

    func testListTablesWithSampleData() async throws {
        try await loadSampleDataIfNeeded()
        let objects = try await session.listTablesAndViews(schema: "echo_test")
        IntegrationTestHelpers.assertContainsObject(objects, name: "departments", type: .table)
        IntegrationTestHelpers.assertContainsObject(objects, name: "employees", type: .table)
        IntegrationTestHelpers.assertContainsObject(objects, name: "products", type: .table)
        IntegrationTestHelpers.assertContainsObject(objects, name: "orders", type: .table)
    }

    func testListViewsWithSampleData() async throws {
        try await loadSampleDataIfNeeded()
        let objects = try await session.listTablesAndViews(schema: "echo_test")
        IntegrationTestHelpers.assertContainsObject(objects, name: "v_active_employees", type: .view)
        IntegrationTestHelpers.assertContainsObject(objects, name: "v_order_summary", type: .view)
    }

    func testListFunctionsWithSampleData() async throws {
        try await loadSampleDataIfNeeded()
        let objects = try await session.listTablesAndViews(schema: "echo_test")
        IntegrationTestHelpers.assertContainsObject(objects, name: "employee_count", type: .function)
        IntegrationTestHelpers.assertContainsObject(objects, name: "full_name", type: .function)
    }

    func testListTriggersWithSampleData() async throws {
        try await loadSampleDataIfNeeded()
        let objects = try await session.listTablesAndViews(schema: "echo_test")
        IntegrationTestHelpers.assertContainsObject(objects, name: "trg_employees_search", type: .trigger)
        IntegrationTestHelpers.assertContainsObject(objects, name: "trg_employees_audit", type: .trigger)
    }

    // MARK: - Helpers

    private func loadSampleDataIfNeeded() async throws {
        let schemas = try await session.listSchemas()
        guard !schemas.contains(where: { $0.caseInsensitiveCompare("echo_test") == .orderedSame }) else {
            return
        }
        let fm = FileManager.default
        let path = "/Users/k/Development/Echo/EchoTests/Integration/Support/SampleData/PostgresSampleData.sql"
        if fm.fileExists(atPath: path) {
            let sql = try String(contentsOfFile: path, encoding: .utf8)
            // Execute the entire script as one batch
            _ = try? await execute(sql)
        } else {
            throw XCTSkip("PostgresSampleData.sql not found — cannot run sample data tests")
        }
    }
}

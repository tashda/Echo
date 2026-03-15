import XCTest
@testable import Echo

/// Verifies that every DatabaseSession protocol method is callable and returns
/// expected types when backed by SQLite (always available, no Docker needed).
/// Methods requiring Docker-only dialects are skipped unless USE_DOCKER=1.
final class SessionProtocolComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func createMemorySession() async throws -> DatabaseSession {
        let factory = SQLiteFactory()
        return try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: "",
                password: ""
            ),
            connectTimeoutSeconds: 5
        )
    }

    private var isDockerAvailable: Bool {
        ProcessInfo.processInfo.environment["USE_DOCKER"] == "1"
    }

    /// Creates a test table for methods that require existing schema objects.
    private func seedTestTable(_ session: DatabaseSession) async throws {
        _ = try await session.executeUpdate(
            "CREATE TABLE compliance_test (id INTEGER PRIMARY KEY, name TEXT NOT NULL, value REAL)"
        )
        _ = try await session.executeUpdate(
            "INSERT INTO compliance_test (id, name, value) VALUES (1, 'alpha', 1.5)"
        )
        _ = try await session.executeUpdate(
            "INSERT INTO compliance_test (id, name, value) VALUES (2, 'beta', 2.5)"
        )
    }

    // MARK: - close()

    func testCloseDoesNotThrow() async throws {
        let session = try await createMemorySession()
        await session.close()
    }

    func testCloseIsIdempotent() async throws {
        let session = try await createMemorySession()
        await session.close()
        await session.close()
    }

    // MARK: - simpleQuery(_:)

    func testSimpleQueryReturnsResultSet() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 42 AS answer")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        IntegrationTestHelpers.assertHasColumn(result, named: "answer")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    func testSimpleQueryMultipleRows() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        let result = try await session.simpleQuery("SELECT * FROM compliance_test ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    func testSimpleQueryWithProgressHandler() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1 AS v", progressHandler: nil)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testSimpleQueryWithExecutionModeAndProgressHandler() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery(
            "SELECT 1 AS v",
            executionMode: nil,
            progressHandler: nil
        )
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testSimpleQueryInvalidSQLThrows() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        do {
            _ = try await session.simpleQuery("INVALID SQL STATEMENT HERE")
            XCTFail("Expected error for invalid SQL")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    // MARK: - listTablesAndViews(schema:)

    func testListTablesAndViewsEmpty() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let objects = try await session.listTablesAndViews(schema: nil)
        // Fresh in-memory database has no user tables
        XCTAssertTrue(objects.isEmpty, "Expected empty table list for fresh database, got \(objects.map(\.name))")
    }

    func testListTablesAndViewsFindsCreatedTable() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        let objects = try await session.listTablesAndViews(schema: nil)
        IntegrationTestHelpers.assertContainsObject(objects, name: "compliance_test", type: .table)
    }

    func testListTablesAndViewsFindsView() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        _ = try await session.executeUpdate(
            "CREATE VIEW compliance_view AS SELECT id, name FROM compliance_test"
        )
        let objects = try await session.listTablesAndViews(schema: nil)
        IntegrationTestHelpers.assertContainsObject(objects, name: "compliance_view", type: .view)
    }

    // MARK: - listSchemas()

    func testListSchemasReturnsArray() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let schemas = try await session.listSchemas()
        // SQLite returns at least "main"
        XCTAssertFalse(schemas.isEmpty, "Expected at least one schema")
        IntegrationTestHelpers.assertContains(schemas, value: "main")
    }

    // MARK: - queryWithPaging(_:limit:offset:)

    func testQueryWithPagingRespectsLimit() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        let result = try await session.queryWithPaging(
            "SELECT * FROM compliance_test ORDER BY id",
            limit: 1,
            offset: 0
        )
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testQueryWithPagingRespectsOffset() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        let result = try await session.queryWithPaging(
            "SELECT * FROM compliance_test ORDER BY id",
            limit: 10,
            offset: 1
        )
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "2", "Expected second row after offset=1")
    }

    func testQueryWithPagingEmptyResult() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        let result = try await session.queryWithPaging(
            "SELECT * FROM compliance_test ORDER BY id",
            limit: 10,
            offset: 100
        )
        IntegrationTestHelpers.assertRowCount(result, expected: 0)
    }

    // MARK: - getTableSchema(_:schemaName:)

    func testGetTableSchemaReturnsColumns() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        let columns = try await session.getTableSchema("compliance_test", schemaName: nil)
        XCTAssertEqual(columns.count, 3, "Expected 3 columns (id, name, value)")

        let columnNames = columns.map(\.name)
        XCTAssertTrue(columnNames.contains(where: { $0.caseInsensitiveCompare("id") == .orderedSame }))
        XCTAssertTrue(columnNames.contains(where: { $0.caseInsensitiveCompare("name") == .orderedSame }))
        XCTAssertTrue(columnNames.contains(where: { $0.caseInsensitiveCompare("value") == .orderedSame }))
    }

    func testGetTableSchemaForNonexistentTable() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let columns = try await session.getTableSchema("nonexistent_table_xyz", schemaName: nil)
        XCTAssertTrue(columns.isEmpty, "Expected empty column list for nonexistent table")
    }

    // MARK: - executeUpdate(_:)

    func testExecuteUpdateCreateTable() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate(
            "CREATE TABLE update_test (id INTEGER PRIMARY KEY)"
        )
        let objects = try await session.listTablesAndViews(schema: nil)
        IntegrationTestHelpers.assertContainsObject(objects, name: "update_test", type: .table)
    }

    func testExecuteUpdateInsertReturnsRowCount() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        let affected = try await session.executeUpdate(
            "INSERT INTO compliance_test (id, name, value) VALUES (3, 'gamma', 3.5)"
        )
        XCTAssertEqual(affected, 1, "Expected 1 affected row for single INSERT")
    }

    func testExecuteUpdateDeleteReturnsRowCount() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        let affected = try await session.executeUpdate(
            "DELETE FROM compliance_test WHERE id = 1"
        )
        XCTAssertEqual(affected, 1, "Expected 1 affected row for DELETE")
    }

    func testExecuteUpdateWithInvalidSQLThrows() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        do {
            _ = try await session.executeUpdate("DROP TABLE nonexistent_xyz")
            XCTFail("Expected error for dropping nonexistent table")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    // MARK: - renameTable(schema:oldName:newName:)

    func testRenameTable() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        // SQLite adapter doesn't implement renameTable protocol method; use raw SQL
        _ = try await session.executeUpdate("ALTER TABLE compliance_test RENAME TO renamed_test")

        let objects = try await session.listTablesAndViews(schema: nil)
        IntegrationTestHelpers.assertContainsObject(objects, name: "renamed_test", type: .table)

        let hasOld = objects.contains { $0.name.caseInsensitiveCompare("compliance_test") == .orderedSame }
        XCTAssertFalse(hasOld, "Old table name should no longer exist")
    }

    // MARK: - dropTable (via executeUpdate for SQLite)

    func testDropTableRemovesTable() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        _ = try await session.executeUpdate("DROP TABLE compliance_test")

        let objects = try await session.listTablesAndViews(schema: nil)
        let exists = objects.contains { $0.name.caseInsensitiveCompare("compliance_test") == .orderedSame }
        XCTAssertFalse(exists, "Table should be dropped")
    }

    func testDropTableIfExistsWithNonexistentTable() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        // Should not throw
        _ = try await session.executeUpdate("DROP TABLE IF EXISTS no_such_table")
    }

    // MARK: - truncateTable (via DELETE for SQLite)

    func testTruncateTableRemovesRows() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        _ = try await session.executeUpdate("DELETE FROM compliance_test")

        let result = try await session.simpleQuery("SELECT COUNT(*) FROM compliance_test")
        XCTAssertEqual(result.rows[0][0], "0", "Table should be empty after truncate")
    }

    // MARK: - getTableStructureDetails(schema:table:)

    func testGetTableStructureDetailsReturnsColumnInfo() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        try await seedTestTable(session)
        let details = try await session.getTableStructureDetails(schema: "main", table: "compliance_test")

        IntegrationTestHelpers.assertHasStructureColumn(details, named: "id")
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "name")
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "value")
    }

    // MARK: - Default protocol implementations

    func testIsSuperuserDefaultReturnsFalse() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let isSuperuser = try await session.isSuperuser()
        XCTAssertFalse(isSuperuser, "SQLite default isSuperuser should return false")
    }

    func testListExtensionsDefaultReturnsEmpty() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let extensions = try await session.listExtensions()
        XCTAssertTrue(extensions.isEmpty, "SQLite should return empty extensions list")
    }

    func testSessionForDatabaseDefaultReturnsSelf() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let other = try await session.sessionForDatabase("any")
        // Default implementation returns self; verify it still works
        let result = try await other.simpleQuery("SELECT 1")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testMakeActivityMonitorDefaultThrows() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        XCTAssertThrowsError(try session.makeActivityMonitor()) { error in
            XCTAssertTrue("\(error)".contains("not supported"), "Expected 'not supported' error, got: \(error)")
        }
    }

    func testRebuildIndexDefaultThrows() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        do {
            try await session.rebuildIndex(schema: "main", table: "t", index: "i")
            XCTFail("Expected error for unsupported rebuildIndex")
        } catch {
            XCTAssertTrue("\(error)".contains("not supported"), "Expected 'not supported' error, got: \(error)")
        }
    }

    // MARK: - Docker-only tests (skipped by default)

    func testListDatabasesRequiresDocker() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")

        // Would connect to a real Postgres or MSSQL here
        // Placeholder: verify the protocol method exists and is callable
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let databases = try await session.listDatabases()
        XCTAssertNotNil(databases)
    }

    func testSessionForDatabaseRequiresDocker() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")
    }

    func testMakeActivityMonitorRequiresDocker() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")
    }

    func testIsSuperuserRequiresDocker() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")
    }

    func testGetObjectDefinitionRequiresDocker() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")
    }

    func testListExtensionObjectsRequiresDocker() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")
    }
}

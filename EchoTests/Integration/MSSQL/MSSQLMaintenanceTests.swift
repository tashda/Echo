import XCTest
@testable import Echo

/// Integration tests for MSSQL maintenance operations.
final class MSSQLMaintenanceTests: MSSQLDockerTestCase {

    func testListFragmentedIndexes() async throws {
        // Create a table and index to ensure we have something to list
        let tableName = uniqueTableName(prefix: "maint_frag")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, val NVARCHAR(200))")
        try await execute("CREATE INDEX [IX_\(tableName)] ON [\(tableName)](val)")
        cleanupSQL("DROP TABLE IF EXISTS [\(tableName)]")

        // Fragmentation might be 0 for a new table, but the query should still succeed
        let fragmented = try await session.listFragmentedIndexes()
        XCTAssertNotNil(fragmented)
    }

    func testGetDatabaseHealth() async throws {
        let health = try await session.getDatabaseHealth()
        XCTAssertGreaterThan(health.sizeMB, 0)
        XCTAssertFalse(health.recoveryModel.isEmpty)
        XCTAssertFalse(health.status.isEmpty)
    }

    func testGetBackupHistory() async throws {
        let history = try await session.getBackupHistory(limit: 5)
        XCTAssertNotNil(history)
    }

    func testCheckDatabaseIntegrity() async throws {
        let result = try await session.checkDatabaseIntegrity()
        XCTAssertTrue(result.succeeded)
    }

    func testShrinkDatabase() async throws {
        let result = try await session.shrinkDatabase()
        XCTAssertTrue(result.succeeded)
    }
}

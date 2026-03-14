import XCTest
@testable import Echo

/// Tests SQL Server index operations through Echo's DatabaseSession layer.
final class MSSQLIndexTests: MSSQLDockerTestCase {

    // MARK: - Create Index

    func testCreateNonClusteredIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_name"
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100), email NVARCHAR(200))")
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("CREATE INDEX [\(indexName)] ON [\(tableName)](name)")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let hasIndex = details.indexes.contains { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertTrue(hasIndex, "Should detect the created index")
    }

    func testCreateUniqueIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "UX_\(tableName)_email"
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, email NVARCHAR(200))")
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("CREATE UNIQUE INDEX [\(indexName)] ON [\(tableName)](email)")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let uniqueIdx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(uniqueIdx)
        XCTAssertTrue(uniqueIdx?.isUnique ?? false)
    }

    func testCreateCompositeIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_composite"
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, last_name NVARCHAR(50), first_name NVARCHAR(50))")
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("CREATE INDEX [\(indexName)] ON [\(tableName)](last_name, first_name)")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let idx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(idx)
        XCTAssertGreaterThanOrEqual(idx?.columns.count ?? 0, 2)
    }

    func testCreateIndexWithSortOrder() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_sorted"
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, score INT, name NVARCHAR(100))")
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("CREATE INDEX [\(indexName)] ON [\(tableName)](score DESC, name ASC)")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let idx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(idx)
    }

    // MARK: - Rebuild Index

    func testRebuildIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_rebuild"
        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100))")
        try await execute("CREATE INDEX [\(indexName)] ON dbo.[\(tableName)](name)")
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        // Insert some data first
        for i in 1...50 {
            try await execute("INSERT INTO dbo.[\(tableName)] VALUES (\(i), 'name_\(i)')")
        }

        // Rebuild should not throw
        try await session.rebuildIndex(schema: "dbo", table: tableName, index: indexName)

        // Verify table still works after rebuild
        let result = try await query("SELECT COUNT(*) AS cnt FROM dbo.[\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "50")
    }

    // MARK: - Drop Index

    func testDropIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_drop"
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100))")
        try await execute("CREATE INDEX [\(indexName)] ON [\(tableName)](name)")
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("DROP INDEX [\(indexName)] ON [\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let hasIndex = details.indexes.contains { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertFalse(hasIndex, "Index should be dropped")
    }

    // MARK: - Filtered Index

    func testCreateFilteredIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_filtered"
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, status NVARCHAR(20), name NVARCHAR(100))")
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("CREATE INDEX [\(indexName)] ON [\(tableName)](name) WHERE status = 'active'")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let idx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(idx)
        // Filter condition may or may not be exposed depending on metadata implementation
    }
}

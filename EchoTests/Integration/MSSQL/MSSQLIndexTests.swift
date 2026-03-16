import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server index operations through Echo's DatabaseSession layer.
final class MSSQLIndexTests: MSSQLDockerTestCase {

    // MARK: - Create Index

    func testCreateNonClusteredIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_name"
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "email", definition: .standard(.init(dataType: .nvarchar(length: .length(200))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.indexes.createIndex(name: indexName, table: tableName, columns: [IndexColumn(name: "name")])

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let hasIndex = details.indexes.contains { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertTrue(hasIndex, "Should detect the created index")
    }

    func testCreateUniqueIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "UX_\(tableName)_email"
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "email", definition: .standard(.init(dataType: .nvarchar(length: .length(200))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.indexes.createUniqueIndex(name: indexName, table: tableName, columns: [IndexColumn(name: "email")])

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let uniqueIdx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(uniqueIdx)
        XCTAssertTrue(uniqueIdx?.isUnique ?? false)
    }

    func testCreateCompositeIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_composite"
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "last_name", definition: .standard(.init(dataType: .nvarchar(length: .length(50))))),
            SQLServerColumnDefinition(name: "first_name", definition: .standard(.init(dataType: .nvarchar(length: .length(50))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.indexes.createIndex(name: indexName, table: tableName, columns: [IndexColumn(name: "last_name"), IndexColumn(name: "first_name")])

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let idx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(idx)
        XCTAssertGreaterThanOrEqual(idx?.columns.count ?? 0, 2)
    }

    func testCreateIndexWithSortOrder() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_sorted"
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "score", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        // Sort order requires raw SQL — no typed API for ASC/DESC column ordering
        try await execute("CREATE INDEX [\(indexName)] ON [\(tableName)](score DESC, name ASC)")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let idx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(idx)
    }

    // MARK: - Rebuild Index

    func testRebuildIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_rebuild"
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.indexes.createIndex(name: indexName, table: tableName, columns: [IndexColumn(name: "name")], schema: "dbo")
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        // Insert some data first
        for i in 1...50 {
            try await sqlserverClient.admin.insertRow(
                into: tableName,
                values: ["id": .int(i), "name": .nString("name_\(i)")]
            )
        }

        // Rebuild should not throw
        try await sqlserverClient.indexes.rebuildIndex(name: indexName, table: tableName, schema: "dbo")

        // Verify table still works after rebuild
        let result = try await query("SELECT COUNT(*) AS cnt FROM dbo.[\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "50")
    }

    // MARK: - Drop Index

    func testDropIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_drop"
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.indexes.createIndex(name: indexName, table: tableName, columns: [IndexColumn(name: "name")])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.indexes.dropIndex(name: indexName, table: tableName)

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let hasIndex = details.indexes.contains { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertFalse(hasIndex, "Index should be dropped")
    }

    // MARK: - Filtered Index

    func testCreateFilteredIndex() async throws {
        let tableName = uniqueTableName()
        let indexName = "IX_\(tableName)_filtered"
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "status", definition: .standard(.init(dataType: .nvarchar(length: .length(20))))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        // Filtered index requires raw SQL — no typed API for WHERE clause on indexes
        try await execute("CREATE INDEX [\(indexName)] ON [\(tableName)](name) WHERE status = 'active'")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let idx = details.indexes.first { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }
        XCTAssertNotNil(idx)
        // Filter condition may or may not be exposed depending on metadata implementation
    }
}

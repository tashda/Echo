import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server transaction operations through Echo's DatabaseSession layer.
final class MSSQLTransactionTests: MSSQLDockerTestCase {

    // MARK: - Basic Transactions

    func testBeginCommitTransaction() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.transactions.beginTransaction()
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "name": .nString("Alice")]
        )
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(2), "name": .nString("Bob")]
        )
        try await sqlserverClient.transactions.commitTransaction()

        let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "2")
    }

    func testBeginRollbackTransaction() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "name": .nString("Before")]
        )
        try await sqlserverClient.transactions.beginTransaction()
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(2), "name": .nString("During")]
        )
        try await sqlserverClient.transactions.rollbackTransaction()

        let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "1", "Rolled-back row should not persist")
    }

    // MARK: - Savepoints

    func testSavepoint() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.transactions.beginTransaction()
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "name": .nString("First")]
        )
        try await sqlserverClient.transactions.createSavepoint(name: "sp1")
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(2), "name": .nString("Second")]
        )
        try await sqlserverClient.transactions.rollbackToSavepoint(name: "sp1")
        try await sqlserverClient.transactions.commitTransaction()

        let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "1", "Only first insert should persist")
    }

    // MARK: - Isolation Levels

    func testReadUncommittedIsolation() async throws {
        try await execute("SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED")
        let result = try await query("SELECT 1 AS test")
        XCTAssertEqual(result.rows[0][0], "1")
    }

    func testReadCommittedIsolation() async throws {
        try await execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
        let result = try await query("SELECT 1 AS test")
        XCTAssertEqual(result.rows[0][0], "1")
    }

    func testSerializableIsolation() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
        try await sqlserverClient.transactions.beginTransaction()
        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1)]
        )
        try await sqlserverClient.transactions.commitTransaction()

        let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "1")
        // Reset isolation level
        try await execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
    }

    // MARK: - Transaction with Error

    func testTransactionRollsBackOnError() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "name": .nString("Existing")]
        )

        do {
            try await sqlserverClient.transactions.beginTransaction()
            try await sqlserverClient.admin.insertRow(
                into: tableName,
                values: ["id": .int(2), "name": .nString("New")]
            )
            // Duplicate PK should fail
            try await sqlserverClient.admin.insertRow(
                into: tableName,
                values: ["id": .int(1), "name": .nString("Duplicate")]
            )
            try await sqlserverClient.transactions.commitTransaction()
        } catch {
            try? await execute("IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION")
        }

        let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
        // Should have only the original row
        XCTAssertEqual(result.rows[0][0], "1")
    }
}

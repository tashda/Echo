import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server transaction operations through Echo's DatabaseSession layer.
///
/// Transaction tests require dedicated connections because transactions are session-local state.
/// The pooled `SQLServerClient` dispatches each `withConnection` call to potentially different
/// connections, so BEGIN/COMMIT/ROLLBACK cannot be reliably paired.
final class MSSQLTransactionTests: MSSQLDedicatedDockerTestCase {

    // MARK: - Basic Transactions

    func testBeginCommitTransaction() async throws {
        let tableName = uniqueTableName()
        try await dedicatedExecute("""
            CREATE TABLE [\(tableName)] (
                id INT PRIMARY KEY,
                name NVARCHAR(100)
            )
        """)
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await dedicatedExecute("BEGIN TRANSACTION")
        try await dedicatedExecute("INSERT INTO [\(tableName)] (id, name) VALUES (1, N'Alice')")
        try await dedicatedExecute("INSERT INTO [\(tableName)] (id, name) VALUES (2, N'Bob')")
        try await dedicatedExecute("COMMIT TRANSACTION")

        let result = try await dedicatedQuery("SELECT COUNT(*) FROM [\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "2")
    }

    func testBeginRollbackTransaction() async throws {
        let tableName = uniqueTableName()
        try await dedicatedExecute("""
            CREATE TABLE [\(tableName)] (
                id INT PRIMARY KEY,
                name NVARCHAR(100)
            )
        """)
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await dedicatedExecute("INSERT INTO [\(tableName)] (id, name) VALUES (1, N'Before')")
        try await dedicatedExecute("BEGIN TRANSACTION")
        try await dedicatedExecute("INSERT INTO [\(tableName)] (id, name) VALUES (2, N'During')")
        try await dedicatedExecute("ROLLBACK TRANSACTION")

        let result = try await dedicatedQuery("SELECT COUNT(*) FROM [\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "1", "Rolled-back row should not persist")
    }

    // MARK: - Savepoints

    func testSavepoint() async throws {
        let tableName = uniqueTableName()
        try await dedicatedExecute("""
            CREATE TABLE [\(tableName)] (
                id INT PRIMARY KEY,
                name NVARCHAR(100)
            )
        """)
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await dedicatedExecute("BEGIN TRANSACTION")
        try await dedicatedExecute("INSERT INTO [\(tableName)] (id, name) VALUES (1, N'First')")
        try await dedicatedExecute("SAVE TRANSACTION sp1")
        try await dedicatedExecute("INSERT INTO [\(tableName)] (id, name) VALUES (2, N'Second')")
        try await dedicatedExecute("ROLLBACK TRANSACTION sp1")
        try await dedicatedExecute("COMMIT TRANSACTION")

        let result = try await dedicatedQuery("SELECT COUNT(*) FROM [\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "1", "Only first insert should persist")
    }

    // MARK: - Isolation Levels

    func testReadUncommittedIsolation() async throws {
        try await dedicatedExecute("SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED")
        let result = try await dedicatedQuery("SELECT 1 AS test")
        XCTAssertEqual(result.rows[0][0], "1")
    }

    func testReadCommittedIsolation() async throws {
        try await dedicatedExecute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
        let result = try await dedicatedQuery("SELECT 1 AS test")
        XCTAssertEqual(result.rows[0][0], "1")
    }

    func testSerializableIsolation() async throws {
        let tableName = uniqueTableName()
        try await dedicatedExecute("""
            CREATE TABLE [\(tableName)] (
                id INT PRIMARY KEY
            )
        """)
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await dedicatedExecute("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
        try await dedicatedExecute("BEGIN TRANSACTION")
        try await dedicatedExecute("INSERT INTO [\(tableName)] (id) VALUES (1)")
        try await dedicatedExecute("COMMIT TRANSACTION")

        let result = try await dedicatedQuery("SELECT COUNT(*) FROM [\(tableName)]")
        XCTAssertEqual(result.rows[0][0], "1")
        // Reset isolation level
        try await dedicatedExecute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
    }

    // MARK: - Transaction with Error

    func testTransactionRollsBackOnError() async throws {
        let tableName = uniqueTableName()
        try await dedicatedExecute("""
            CREATE TABLE [\(tableName)] (
                id INT PRIMARY KEY,
                name NVARCHAR(100)
            )
        """)
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await dedicatedExecute("INSERT INTO [\(tableName)] (id, name) VALUES (1, N'Existing')")

        do {
            try await dedicatedExecute("BEGIN TRANSACTION")
            try await dedicatedExecute("INSERT INTO [\(tableName)] (id, name) VALUES (2, N'New')")
            // Duplicate PK should fail
            try await dedicatedExecute("INSERT INTO [\(tableName)] (id, name) VALUES (1, N'Duplicate')")
            try await dedicatedExecute("COMMIT TRANSACTION")
        } catch {
            try? await dedicatedExecute("IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION")
        }

        let result = try await dedicatedQuery("SELECT COUNT(*) FROM [\(tableName)]")
        // Should have only the original row
        XCTAssertEqual(result.rows[0][0], "1")
    }
}

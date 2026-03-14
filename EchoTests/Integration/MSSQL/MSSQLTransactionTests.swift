import XCTest
@testable import Echo

/// Tests SQL Server transaction operations through Echo's DatabaseSession layer.
final class MSSQLTransactionTests: MSSQLDockerTestCase {

    // MARK: - Basic Transactions

    func testBeginCommitTransaction() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name NVARCHAR(100)") { tableName in
            try await execute("BEGIN TRANSACTION")
            try await execute("INSERT INTO [\(tableName)] VALUES (1, 'Alice')")
            try await execute("INSERT INTO [\(tableName)] VALUES (2, 'Bob')")
            try await execute("COMMIT TRANSACTION")

            let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
            XCTAssertEqual(result.rows[0][0], "2")
        }
    }

    func testBeginRollbackTransaction() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name NVARCHAR(100)") { tableName in
            try await execute("INSERT INTO [\(tableName)] VALUES (1, 'Before')")
            try await execute("BEGIN TRANSACTION")
            try await execute("INSERT INTO [\(tableName)] VALUES (2, 'During')")
            try await execute("ROLLBACK TRANSACTION")

            let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
            XCTAssertEqual(result.rows[0][0], "1", "Rolled-back row should not persist")
        }
    }

    // MARK: - Savepoints

    func testSavepoint() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name NVARCHAR(100)") { tableName in
            try await execute("BEGIN TRANSACTION")
            try await execute("INSERT INTO [\(tableName)] VALUES (1, 'First')")
            try await execute("SAVE TRANSACTION sp1")
            try await execute("INSERT INTO [\(tableName)] VALUES (2, 'Second')")
            try await execute("ROLLBACK TRANSACTION sp1")
            try await execute("COMMIT TRANSACTION")

            let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
            XCTAssertEqual(result.rows[0][0], "1", "Only first insert should persist")
        }
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
        try await execute("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
        try await withTempTable(columns: "id INT PRIMARY KEY") { tableName in
            try await execute("BEGIN TRANSACTION")
            try await execute("INSERT INTO [\(tableName)] VALUES (1)")
            try await execute("COMMIT TRANSACTION")

            let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
            XCTAssertEqual(result.rows[0][0], "1")
        }
        // Reset isolation level
        try await execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
    }

    // MARK: - Transaction with Error

    func testTransactionRollsBackOnError() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name NVARCHAR(100)") { tableName in
            try await execute("INSERT INTO [\(tableName)] VALUES (1, 'Existing')")

            do {
                try await execute("BEGIN TRANSACTION")
                try await execute("INSERT INTO [\(tableName)] VALUES (2, 'New')")
                // Duplicate PK should fail
                try await execute("INSERT INTO [\(tableName)] VALUES (1, 'Duplicate')")
                try await execute("COMMIT TRANSACTION")
            } catch {
                try? await execute("IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION")
            }

            let result = try await query("SELECT COUNT(*) FROM [\(tableName)]")
            // Should have only the original row
            XCTAssertEqual(result.rows[0][0], "1")
        }
    }
}

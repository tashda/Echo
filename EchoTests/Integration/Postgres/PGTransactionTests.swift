import XCTest
@testable import Echo

/// Tests PostgreSQL transaction operations through Echo's DatabaseSession layer.
final class PGTransactionTests: PostgresDockerTestCase {

    // MARK: - Basic Transactions

    func testBeginCommit() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await execute("BEGIN")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('Alice')")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('Bob')")
            try await execute("COMMIT")

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "2")
        }
    }

    func testBeginRollback() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await execute("INSERT INTO \(tableName) (name) VALUES ('Before')")
            try await execute("BEGIN")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('During')")
            try await execute("ROLLBACK")

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "1", "Rolled-back row should not persist")
        }
    }

    // MARK: - Savepoints

    func testSavepointAndRollbackTo() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await execute("BEGIN")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('First')")
            try await execute("SAVEPOINT sp1")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('Second')")
            try await execute("ROLLBACK TO SAVEPOINT sp1")
            try await execute("COMMIT")

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "1", "Only first insert should persist")
        }
    }

    func testNestedSavepoints() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await execute("BEGIN")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('A')")
            try await execute("SAVEPOINT sp1")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('B')")
            try await execute("SAVEPOINT sp2")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('C')")
            try await execute("ROLLBACK TO SAVEPOINT sp2")
            // 'C' is rolled back, 'B' and 'A' remain
            try await execute("COMMIT")

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "2", "A and B should persist, C rolled back")
        }
    }

    func testReleaseSavepoint() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await execute("BEGIN")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('X')")
            try await execute("SAVEPOINT sp1")
            try await execute("INSERT INTO \(tableName) (name) VALUES ('Y')")
            try await execute("RELEASE SAVEPOINT sp1")
            try await execute("COMMIT")

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "2", "Both rows should persist after release")
        }
    }

    // MARK: - Isolation Levels

    func testReadCommittedIsolation() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, value INT") { tableName in
            try await execute("BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED")
            try await execute("INSERT INTO \(tableName) (value) VALUES (42)")
            try await execute("COMMIT")

            let result = try await query("SELECT value FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "42")
        }
    }

    func testRepeatableReadIsolation() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, value INT") { tableName in
            try await execute("INSERT INTO \(tableName) (value) VALUES (1)")

            try await execute("BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ")
            let r1 = try await query("SELECT value FROM \(tableName)")
            XCTAssertEqual(r1.rows[0][0], "1")
            try await execute("COMMIT")
        }
    }

    func testSerializableIsolation() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, value INT") { tableName in
            try await execute("BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE")
            try await execute("INSERT INTO \(tableName) (value) VALUES (100)")
            try await execute("COMMIT")

            let result = try await query("SELECT value FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "100")
        }
    }

    // MARK: - Transaction with Error

    func testTransactionRollsBackOnError() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name TEXT") { tableName in
            try await execute("INSERT INTO \(tableName) VALUES (1, 'Existing')")

            do {
                try await execute("BEGIN")
                try await execute("INSERT INTO \(tableName) VALUES (2, 'New')")
                // Duplicate PK should fail
                try await execute("INSERT INTO \(tableName) VALUES (1, 'Duplicate')")
                try await execute("COMMIT")
            } catch {
                try? await execute("ROLLBACK")
            }

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "1", "Only original row should remain")
        }
    }

    func testTransactionErrorRequiresRollback() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY") { tableName in
            try await execute("BEGIN")
            try await execute("INSERT INTO \(tableName) VALUES (1)")

            do {
                // Invalid SQL should cause error
                try await execute("INSERT INTO \(tableName) VALUES (1)")
                XCTFail("Duplicate key should throw")
            } catch {
                // After error in PG, transaction is aborted — must rollback
                try await execute("ROLLBACK")
            }

            // After rollback, new operations should work
            try await execute("INSERT INTO \(tableName) VALUES (1)")
            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "1")
        }
    }
}

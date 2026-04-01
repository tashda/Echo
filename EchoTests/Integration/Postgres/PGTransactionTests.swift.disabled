import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL transaction operations through Echo's DatabaseSession layer.
final class PGTransactionTests: PostgresDockerTestCase {

    // MARK: - Basic Transactions

    func testBeginCommit() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await postgresClient.connection.beginTransaction()
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["Alice"]])
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["Bob"]])
            try await postgresClient.connection.commit()

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "2")
        }
    }

    func testBeginRollback() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["Before"]])
            try await postgresClient.connection.beginTransaction()
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["During"]])
            try await postgresClient.connection.rollback()

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "1", "Rolled-back row should not persist")
        }
    }

    // MARK: - Savepoints

    func testSavepointAndRollbackTo() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await postgresClient.connection.beginTransaction()
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["First"]])
            try await postgresClient.connection.createSavepoint("sp1")
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["Second"]])
            try await postgresClient.connection.rollbackToSavepoint("sp1")
            try await postgresClient.connection.commit()

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "1", "Only first insert should persist")
        }
    }

    func testNestedSavepoints() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await postgresClient.connection.beginTransaction()
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["A"]])
            try await postgresClient.connection.createSavepoint("sp1")
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["B"]])
            try await postgresClient.connection.createSavepoint("sp2")
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["C"]])
            try await postgresClient.connection.rollbackToSavepoint("sp2")
            // 'C' is rolled back, 'B' and 'A' remain
            try await postgresClient.connection.commit()

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "2", "A and B should persist, C rolled back")
        }
    }

    func testReleaseSavepoint() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, name TEXT") { tableName in
            try await postgresClient.connection.beginTransaction()
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["X"]])
            try await postgresClient.connection.createSavepoint("sp1")
            try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["Y"]])
            try await postgresClient.connection.releaseSavepoint("sp1")
            try await postgresClient.connection.commit()

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "2", "Both rows should persist after release")
        }
    }

    // MARK: - Isolation Levels

    func testReadCommittedIsolation() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, value INT") { tableName in
            try await postgresClient.connection.beginTransaction(isolation: .readCommitted)
            try await postgresClient.connection.insert(into: tableName, columns: ["value"], values: [[42]])
            try await postgresClient.connection.commit()

            let result = try await query("SELECT value FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "42")
        }
    }

    func testRepeatableReadIsolation() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, value INT") { tableName in
            try await postgresClient.connection.insert(into: tableName, columns: ["value"], values: [[1]])

            try await postgresClient.connection.beginTransaction(isolation: .repeatableRead)
            let r1 = try await query("SELECT value FROM \(tableName)")
            XCTAssertEqual(r1.rows[0][0], "1")
            try await postgresClient.connection.commit()
        }
    }

    func testSerializableIsolation() async throws {
        try await withTempTable(columns: "id SERIAL PRIMARY KEY, value INT") { tableName in
            try await postgresClient.connection.beginTransaction(isolation: .serializable)
            try await postgresClient.connection.insert(into: tableName, columns: ["value"], values: [[100]])
            try await postgresClient.connection.commit()

            let result = try await query("SELECT value FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "100")
        }
    }

    // MARK: - Transaction with Error

    func testTransactionRollsBackOnError() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name TEXT") { tableName in
            try await postgresClient.connection.insert(into: tableName, columns: ["id", "name"], values: [[1, "Existing"]])

            do {
                try await postgresClient.connection.beginTransaction()
                try await postgresClient.connection.insert(into: tableName, columns: ["id", "name"], values: [[2, "New"]])
                // Duplicate PK should fail
                try await postgresClient.connection.insert(into: tableName, columns: ["id", "name"], values: [[1, "Duplicate"]])
                try await postgresClient.connection.commit()
            } catch {
                try? await postgresClient.connection.rollback()
            }

            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "1", "Only original row should remain")
        }
    }

    func testTransactionErrorRequiresRollback() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY") { tableName in
            try await postgresClient.connection.beginTransaction()
            try await postgresClient.connection.insert(into: tableName, columns: ["id"], values: [[1]])

            do {
                // Invalid SQL should cause error
                try await postgresClient.connection.insert(into: tableName, columns: ["id"], values: [[1]])
                XCTFail("Duplicate key should throw")
            } catch {
                // After error in PG, transaction is aborted — must rollback
                try await postgresClient.connection.rollback()
            }

            // After rollback, new operations should work
            try await postgresClient.connection.insert(into: tableName, columns: ["id"], values: [[1]])
            let result = try await query("SELECT COUNT(*) FROM \(tableName)")
            XCTAssertEqual(result.rows[0][0], "1")
        }
    }
}

import XCTest
@testable import Echo

/// Tests SQLite connection lifecycle through Echo's DatabaseSession layer.
/// These tests require no Docker — they use in-memory databases.
final class SQLiteConnectionTests: XCTestCase {

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

    // MARK: - Basic Connectivity

    func testOpenMemoryDatabase() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1 AS value")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0][0], "1")
    }

    func testCloseSession() async throws {
        let session = try await createMemorySession()
        await session.close()
        // Should not crash on close
    }

    func testMultipleSequentialSessions() async throws {
        for i in 0..<3 {
            let session = try await createMemorySession()
            let result = try await session.simpleQuery("SELECT \(i) AS val")
            XCTAssertEqual(result.rows[0][0], "\(i)")
            await session.close()
        }
    }

    // MARK: - File-based Database

    func testOpenFileDatabase() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("echo_test_\(UUID().uuidString).db").path
        defer { try? FileManager.default.removeItem(atPath: dbPath) }

        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: dbPath,
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
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
        _ = try await session.executeUpdate("INSERT INTO test VALUES (1, 'hello')")
        let result = try await session.simpleQuery("SELECT name FROM test")
        XCTAssertEqual(result.rows[0][0], "hello")
    }

    // MARK: - Error Handling

    func testInvalidQueryReturnsError() async throws {
        let session = try await createMemorySession()
        defer { Task { @MainActor in await session.close() } }

        do {
            _ = try await session.simpleQuery("SELECT * FROM nonexistent_table")
            XCTFail("Expected error for nonexistent table")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }
}

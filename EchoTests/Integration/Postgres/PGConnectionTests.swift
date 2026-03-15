import XCTest
@testable import Echo

/// Tests PostgreSQL connection lifecycle through Echo's DatabaseSession layer.
final class PGConnectionTests: PostgresDockerTestCase {

    // MARK: - Basic Connectivity

    func testConnectAndSelect1() async throws {
        let result = try await query("SELECT 1 AS value")
        XCTAssertEqual(result.columns.count, 1)
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0][0], "1")
    }

    func testConnectionClosesCleanly() async throws {
        let extraSession = try await createSession()
        let result = try await extraSession.simpleQuery("SELECT 1 AS alive")
        XCTAssertEqual(result.rows.count, 1)
        await extraSession.close()
        // Closing should not throw; session is done.
    }

    func testReconnectAfterClose() async throws {
        let firstSession = try await createSession()
        let r1 = try await firstSession.simpleQuery("SELECT 'first' AS tag")
        XCTAssertEqual(r1.rows[0][0], "first")
        await firstSession.close()

        // Reconnect with a fresh session
        let secondSession = try await createSession()
        let r2 = try await secondSession.simpleQuery("SELECT 'second' AS tag")
        XCTAssertEqual(r2.rows[0][0], "second")
        await secondSession.close()
    }

    func testMultipleSequentialConnections() async throws {
        for i in 0..<3 {
            let s = try await createSession()
            let result = try await s.simpleQuery("SELECT \(i) AS iteration")
            XCTAssertEqual(result.rows[0][0], "\(i)")
            await s.close()
        }
    }

    // MARK: - Superuser Check

    func testIsSuperuser() async throws {
        // 'postgres' user should be a superuser
        let isSuperuser = try await session.isSuperuser()
        XCTAssertTrue(isSuperuser, "postgres user should be superuser")
    }

    // MARK: - Multi-Database

    func testSessionForDatabase() async throws {
        let dbName = uniqueName(prefix: "echo_db")
        try await execute("CREATE DATABASE \(dbName)")
        cleanupSQL("DROP DATABASE IF EXISTS \(dbName)")

        let dbSession = try await session.sessionForDatabase(dbName)
        defer { Task { @MainActor in await dbSession.close() } }

        // Should be able to query in the new database
        let result = try await dbSession.simpleQuery("SELECT current_database() AS current_db")
        XCTAssertEqual(result.rows[0][0], dbName)
    }

    func testMultipleDatabaseSessions() async throws {
        let db1 = uniqueName(prefix: "echo_db1")
        let db2 = uniqueName(prefix: "echo_db2")
        try await execute("CREATE DATABASE \(db1)")
        try await execute("CREATE DATABASE \(db2)")
        cleanupSQL(
            "DROP DATABASE IF EXISTS \(db1)",
            "DROP DATABASE IF EXISTS \(db2)"
        )

        let session1 = try await session.sessionForDatabase(db1)
        let session2 = try await session.sessionForDatabase(db2)
        defer {
            Task { @MainActor in
                await session1.close()
                await session2.close()
            }
        }

        let r1 = try await session1.simpleQuery("SELECT current_database()")
        let r2 = try await session2.simpleQuery("SELECT current_database()")
        XCTAssertEqual(r1.rows[0][0], db1)
        XCTAssertEqual(r2.rows[0][0], db2)
    }

    // MARK: - Connection Parameters

    func testConnectionWithPostgresNIOFactory() async throws {
        let factory = PostgresNIOFactory()
        let s = try await factory.connect(
            host: "127.0.0.1",
            port: Self.port,
            database: Self.database,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: Self.username,
                password: Self.password
            ),
            connectTimeoutSeconds: 15
        )
        defer { Task { @MainActor in await s.close() } }

        let result = try await s.simpleQuery("SELECT 1 AS test")
        XCTAssertEqual(result.rows.count, 1)
    }

    func testConnectionToSpecificDatabase() async throws {
        let dbName = uniqueName(prefix: "echo_conndb")
        try await execute("CREATE DATABASE \(dbName)")
        cleanupSQL("DROP DATABASE IF EXISTS \(dbName)")

        let dbSession = try await createSession(database: dbName)
        defer { Task { @MainActor in await dbSession.close() } }

        let result = try await dbSession.simpleQuery("SELECT current_database() AS db")
        XCTAssertEqual(result.rows[0][0], dbName)
    }

    // MARK: - Error Handling

    func testInvalidAuthenticationFails() async throws {
        let factory = PostgresNIOFactory()
        do {
            let s = try await factory.connect(
                host: "127.0.0.1",
                port: Self.port,
                database: Self.database,
                tls: false,
                authentication: DatabaseAuthenticationConfiguration(
                    method: .sqlPassword,
                    username: "nonexistent_user",
                    password: "wrong_password"
                ),
                connectTimeoutSeconds: 10
            )
            await s.close()
            XCTFail("Expected authentication failure")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    func testInvalidQueryReturnsError() async throws {
        do {
            _ = try await query("SELECT * FROM nonexistent_table_xyz")
            XCTFail("Expected error for invalid table")
        } catch {
            // Should get a meaningful error, not a crash
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    func testSyntaxErrorReturnsError() async throws {
        do {
            _ = try await query("SELEC INVALID SYNTAX")
            XCTFail("Expected syntax error")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }
}

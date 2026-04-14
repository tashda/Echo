import XCTest
@testable import Echo

/// Tests SQL Server connection lifecycle through Echo's DatabaseSession layer.
final class MSSQLConnectionTests: MSSQLDockerTestCase {

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
        // 'sa' should be a superuser (sysadmin)
        let isSuperuser = try await session.isSuperuser()
        XCTAssertTrue(isSuperuser, "sa should be superuser/sysadmin")
    }

    // MARK: - Multi-Database

    func testSessionForDatabase() async throws {
        // Create a test database
        let dbName = uniqueTableName(prefix: "echo_db")
        try await execute("CREATE DATABASE [\(dbName)]")
        cleanupSQL("DROP DATABASE [\(dbName)]")

        let dbSession = try await session.sessionForDatabase(dbName)

        // Should be able to query in the new database
        let result = try await dbSession.simpleQuery("SELECT DB_NAME() AS current_db")
        XCTAssertEqual(result.rows[0][0], dbName)

        // Close synchronously within the test to avoid EventLoop lifecycle issues
        await dbSession.close()
    }

    func testListDatabasesIncludesMaster() async throws {
        let databases = try await session.listDatabases()
        XCTAssertFalse(databases.isEmpty)
        IntegrationTestHelpers.assertContains(databases, value: "master")
    }

    // MARK: - Connection with Different Auth Parameters

    func testConnectionWithTrustServerCertificate() async throws {
        let factory = MSSQLNIOFactory()
        let s = try await factory.connect(
            host: "127.0.0.1",
            port: Self.port,
            database: nil,
            tls: false,
            trustServerCertificate: true,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: Self.username,
                password: Self.password
            ),
            connectTimeoutSeconds: 15
        )
        let result = try await s.simpleQuery("SELECT 1 AS test")
        XCTAssertEqual(result.rows.count, 1)
        await s.close()
    }

    func testConnectionWithReadOnlyIntent() async throws {
        let factory = MSSQLNIOFactory()
        let s = try await factory.connect(
            host: "127.0.0.1",
            port: Self.port,
            database: nil,
            tls: false,
            trustServerCertificate: true,
            readOnlyIntent: true,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: Self.username,
                password: Self.password
            ),
            connectTimeoutSeconds: 15
        )

        let result = try await s.simpleQuery("SELECT 1 AS readonly_test")
        XCTAssertEqual(result.rows.count, 1)
        await s.close()
    }

    // MARK: - Error Handling

    func testInvalidQueryReturnsError() async throws {
        do {
            _ = try await query("SELECT * FROM nonexistent_table_xyz")
            XCTFail("Expected error for invalid table")
        } catch {
            // Should get a meaningful error, not a crash
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    func testInvalidAuthenticationFails() async throws {
        let factory = MSSQLNIOFactory()
        do {
            let s = try await factory.connect(
                host: "127.0.0.1",
                port: Self.port,
                database: nil,
                tls: false,
                trustServerCertificate: true,
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
}

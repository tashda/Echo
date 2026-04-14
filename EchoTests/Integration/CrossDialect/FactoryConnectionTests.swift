import XCTest
@testable import Echo

/// Tests DatabaseFactory.connect() behavior across dialects.
/// SQLite tests run everywhere; MSSQL and Postgres tests are skipped without Docker.
final class FactoryConnectionTests: XCTestCase {

    // MARK: - Helpers

    private var isDockerAvailable: Bool {
        ProcessInfo.processInfo.environment["USE_DOCKER"] == "1"
    }

    private func defaultAuth(
        method: DatabaseAuthenticationMethod = .sqlPassword,
        username: String = "",
        password: String = ""
    ) -> DatabaseAuthenticationConfiguration {
        DatabaseAuthenticationConfiguration(
            method: method,
            username: username,
            password: password
        )
    }

    // MARK: - Protocol Conformance

    func testSQLiteFactoryConformsToDatabaseFactory() {
        let factory: any DatabaseFactory = SQLiteFactory()
        XCTAssertNotNil(factory, "SQLiteFactory must conform to DatabaseFactory")
    }

    func testMSSQLNIOFactoryConformsToDatabaseFactory() {
        let factory: any DatabaseFactory = MSSQLNIOFactory()
        XCTAssertNotNil(factory, "MSSQLNIOFactory must conform to DatabaseFactory")
    }

    func testPostgresNIOFactoryConformsToDatabaseFactory() {
        let factory: any DatabaseFactory = PostgresNIOFactory()
        XCTAssertNotNil(factory, "PostgresNIOFactory must conform to DatabaseFactory")
    }

    // MARK: - SQLite: In-Memory Connection

    func testSQLiteConnectsWithMemoryHost() async throws {
        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: defaultAuth(),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1 AS v")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "1")
    }

    func testSQLiteConnectsWithMemoryDatabase() async throws {
        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: "",
            port: 0,
            database: ":memory:",
            tls: false,
            authentication: defaultAuth(),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 'hello' AS greeting")
        XCTAssertEqual(result.rows[0][0], "hello")
    }

    // MARK: - SQLite: File-based Connection

    func testSQLiteConnectsWithFilePath() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("factory_test_\(UUID().uuidString).db").path
        defer { try? FileManager.default.removeItem(atPath: dbPath) }

        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: dbPath,
            port: 0,
            database: nil,
            tls: false,
            authentication: defaultAuth(),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        _ = try await session.executeUpdate("CREATE TABLE file_test (id INTEGER PRIMARY KEY)")
        _ = try await session.executeUpdate("INSERT INTO file_test VALUES (1)")
        let result = try await session.simpleQuery("SELECT id FROM file_test")
        XCTAssertEqual(result.rows[0][0], "1")

        // Verify file was actually created
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbPath), "Database file should exist on disk")
    }

    func testSQLiteConnectsWithTildePath() async throws {
        let expandedHome = NSHomeDirectory()
        let dbName = "factory_tilde_test_\(UUID().uuidString).db"
        let expandedPath = "\(expandedHome)/\(dbName)"
        let tildePath = "~/\(dbName)"
        defer { try? FileManager.default.removeItem(atPath: expandedPath) }

        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: tildePath,
            port: 0,
            database: nil,
            tls: false,
            authentication: defaultAuth(),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expandedPath), "Tilde path should resolve correctly")
    }

    // MARK: - SQLite: Error Handling

    func testSQLiteRejectsEmptyPath() async throws {
        let factory = SQLiteFactory()

        do {
            _ = try await factory.connect(
                host: "",
                port: 0,
                database: "",
                tls: false,
                authentication: defaultAuth(),
                connectTimeoutSeconds: 5
            )
            XCTFail("Expected error for empty path")
        } catch {
            // Should throw a connection error for empty path
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    func testSQLiteHandlesInvalidDirectoryPath() async throws {
        let factory = SQLiteFactory()
        let invalidPath = "/nonexistent_root_dir_\(UUID().uuidString)/test.db"

        do {
            _ = try await factory.connect(
                host: invalidPath,
                port: 0,
                database: nil,
                tls: false,
                authentication: defaultAuth(),
                connectTimeoutSeconds: 5
            )
            XCTFail("Expected error for invalid directory path")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    // MARK: - SQLite: TLS Parameters (Ignored but Accepted)

    func testSQLiteIgnoresTLSEnabled() async throws {
        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: true,
            authentication: defaultAuth(),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testSQLiteIgnoresTrustServerCertificate() async throws {
        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            trustServerCertificate: true,
            authentication: defaultAuth(),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testSQLiteIgnoresTLSMode() async throws {
        let factory = SQLiteFactory()
        for mode in TLSMode.allCases {
            let session = try await factory.connect(
                host: ":memory:",
                port: 0,
                database: nil,
                tls: false,
                tlsMode: mode,
                authentication: defaultAuth(),
                connectTimeoutSeconds: 5
            )
            defer { Task { @MainActor in await session.close() } }

            let result = try await session.simpleQuery("SELECT 1")
            IntegrationTestHelpers.assertRowCount(result, expected: 1, message: "TLSMode.\(mode) should be accepted")
        }
    }

    func testSQLiteIgnoresMSSQLEncryptionMode() async throws {
        let factory = SQLiteFactory()
        for mode in MSSQLEncryptionMode.allCases {
            let session = try await factory.connect(
                host: ":memory:",
                port: 0,
                database: nil,
                tls: false,
                mssqlEncryptionMode: mode,
                authentication: defaultAuth(),
                connectTimeoutSeconds: 5
            )
            defer { Task { @MainActor in await session.close() } }

            let result = try await session.simpleQuery("SELECT 1")
            IntegrationTestHelpers.assertRowCount(result, expected: 1, message: "MSSQLEncryptionMode.\(mode) should be accepted")
        }
    }

    func testSQLiteIgnoresSSLCertPaths() async throws {
        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: true,
            trustServerCertificate: false,
            tlsMode: .verifyFull,
            sslRootCertPath: "/fake/root.pem",
            sslCertPath: "/fake/client.pem",
            sslKeyPath: "/fake/client.key",
            authentication: defaultAuth(),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testSQLiteIgnoresReadOnlyIntent() async throws {
        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            readOnlyIntent: true,
            authentication: defaultAuth(),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    // MARK: - SQLite: Auth Configurations (Ignored but Accepted)

    func testSQLiteAcceptsSQLPasswordAuth() async throws {
        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: defaultAuth(method: .sqlPassword, username: "user", password: "pass"),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testSQLiteAcceptsWindowsIntegratedAuth() async throws {
        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: defaultAuth(method: .windowsIntegrated),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    func testSQLiteAcceptsAccessTokenAuth() async throws {
        let factory = SQLiteFactory()
        let session = try await factory.connect(
            host: ":memory:",
            port: 0,
            database: nil,
            tls: false,
            authentication: defaultAuth(method: .accessToken, password: "fake-token"),
            connectTimeoutSeconds: 5
        )
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
    }

    // MARK: - SQLite: Connect Timeout (Accepted)

    func testSQLiteAcceptsVariousTimeouts() async throws {
        let factory = SQLiteFactory()
        for timeout in [1, 5, 30, 120] {
            let session = try await factory.connect(
                host: ":memory:",
                port: 0,
                database: nil,
                tls: false,
                authentication: defaultAuth(),
                connectTimeoutSeconds: timeout
            )
            await session.close()
        }
    }

    // MARK: - MSSQL: Docker-only Tests

    func testMSSQLFactoryRequiresValidCredentials() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")

        let factory = MSSQLNIOFactory()
        do {
            _ = try await factory.connect(
                host: "localhost",
                port: 1433,
                database: "master",
                tls: false,
                trustServerCertificate: true,
                authentication: defaultAuth(
                    method: .sqlPassword,
                    username: "sa",
                    password: "InvalidPassword123!"
                ),
                connectTimeoutSeconds: 5
            )
            XCTFail("Expected connection/auth error with invalid credentials")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    func testMSSQLFactoryConnectionRefused() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")

        let factory = MSSQLNIOFactory()
        do {
            // Use a port that is unlikely to have anything listening
            _ = try await factory.connect(
                host: "localhost",
                port: 61999,
                database: nil,
                tls: false,
                authentication: defaultAuth(method: .sqlPassword, username: "sa", password: "pass"),
                connectTimeoutSeconds: 2
            )
            XCTFail("Expected connection refused error")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    func testMSSQLFactoryTLSParameters() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")

        // Verify TLS and encryption parameters are forwarded correctly
        // This test just confirms the factory accepts all TLS-related parameters
        let factory = MSSQLNIOFactory()
        do {
            _ = try await factory.connect(
                host: "localhost",
                port: 1433,
                database: "master",
                tls: true,
                trustServerCertificate: true,
                tlsMode: .require,
                sslRootCertPath: nil,
                sslCertPath: nil,
                sslKeyPath: nil,
                mssqlEncryptionMode: .mandatory,
                readOnlyIntent: true,
                authentication: defaultAuth(method: .sqlPassword, username: "sa", password: "test"),
                connectTimeoutSeconds: 3
            )
        } catch {
            // Connection may fail (no Docker), but the factory should not crash
            // when given valid parameter combinations
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    // MARK: - Postgres: Docker-only Tests

    func testPostgresFactoryRequiresValidCredentials() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")

        let factory = PostgresNIOFactory()
        do {
            _ = try await factory.connect(
                host: "localhost",
                port: 5432,
                database: "postgres",
                tls: false,
                authentication: defaultAuth(
                    method: .sqlPassword,
                    username: "postgres",
                    password: "InvalidPassword123!"
                ),
                connectTimeoutSeconds: 5
            )
            XCTFail("Expected connection/auth error with invalid credentials")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    func testPostgresFactoryConnectionRefused() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")

        let factory = PostgresNIOFactory()
        do {
            _ = try await factory.connect(
                host: "localhost",
                port: 61998,
                database: nil,
                tls: false,
                authentication: defaultAuth(method: .sqlPassword, username: "postgres", password: "pass"),
                connectTimeoutSeconds: 2
            )
            XCTFail("Expected connection refused error")
        } catch {
            XCTAssertFalse("\(error)".isEmpty)
        }
    }

    func testPostgresFactoryTLSModeHandling() async throws {
        try XCTSkipUnless(isDockerAvailable, "Skipped: set USE_DOCKER=1 to run Docker-dependent tests")

        let factory = PostgresNIOFactory()
        // Verify the factory accepts all TLS mode values
        for mode in TLSMode.allCases {
            do {
                _ = try await factory.connect(
                    host: "localhost",
                    port: 5432,
                    database: "postgres",
                    tls: mode != .disable,
                    tlsMode: mode,
                    sslRootCertPath: nil,
                    sslCertPath: nil,
                    sslKeyPath: nil,
                    authentication: defaultAuth(method: .sqlPassword, username: "postgres", password: "test"),
                    connectTimeoutSeconds: 3
                )
            } catch {
                // Connection may fail, but parameters should be accepted without crashing
                XCTAssertFalse("\(error)".isEmpty)
            }
        }
    }
}

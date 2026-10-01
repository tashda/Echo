import XCTest
import ServerLabClient
@testable import Echo

@MainActor
final class MySQLIntegrationTests: XCTestCase {
    private struct MySQLConfig {
        let host: String
        let port: Int
        let database: String
        let username: String
        let password: String
    }

    /// The lab MySQL the suites share (`LabSharedServers`); the tests only read.
    private func loadConfig() async throws -> MySQLConfig {
        let server = try await labServer(LabRecipes.mysql)
        return MySQLConfig(host: server.host, port: server.port, database: "mysql",
                           username: server.username, password: server.password)
    }

    /// TLS Required: MySQL 8.4 signs in with caching_sha2_password, which needs TLS (decision D18).
    private func connect(config: MySQLConfig, tls: Bool = true) async throws -> DatabaseSession {
        let factory = MySQLNIOFactory()
        return try await factory.connect(
            host: config.host,
            port: config.port,
            database: config.database,
            tls: tls,
            tlsMode: .require,
            authentication: DatabaseAuthenticationConfiguration(
                username: config.username,
                password: config.password
            )
        )
    }

    /// Without TLS, the first caching_sha2_password sign-in is refused rather than fetch the
    /// server's RSA key in plaintext, and the error says what to do (#31, decision D18).
    func testSignInWithoutTLSSaysItNeedsTLS() async throws {
        let config = try await loadConfig()
        do {
            let session = try await connect(config: config, tls: false)
            _ = try await session.simpleQuery("SELECT 1")
            await session.close()
            // The account may already be in the server's cache from a TLS sign-in: then it works.
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("needs TLS"), error.localizedDescription)
        }
    }

    // MARK: - Basic Connectivity

    func testSimpleQuerySelect1() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.simpleQuery("SELECT 1 AS value")
        XCTAssertEqual(result.columns.count, 1)
        XCTAssertEqual(result.rows.count, 1)
    }

    // MARK: - Schema Discovery

    func testListDatabases() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        // The lab server is empty: only system databases, which the explorer hides.
        let databases = try await session.listDatabases()
        XCTAssertFalse(databases.contains { ["mysql", "sys", "information_schema", "performance_schema"].contains($0) }, "\(databases)")
    }

    func testListTablesAndViews() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let objects = try await session.listTablesAndViews(schema: nil)
        XCTAssertNotNil(objects)
    }

    // MARK: - Query With Paging

    func testQueryWithPaging() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.queryWithPaging(
            "SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3",
            limit: 2,
            offset: 0
        )
        XCTAssertEqual(result.rows.count, 2)
    }

    // MARK: - Scripts

    /// #36: a script runs statement by statement on one connection, each with its own result,
    /// and stops at the first failure, reporting the rest as not run.
    func testScriptStopsAtTheFirstFailure() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let results = try await session.executeBatches([
            "SET @echo_script = 41", "SELECT @echo_script + 1 AS answer", "SELECT * FROM missing_table_xyz", "SELECT 3",
        ], progressHandler: nil)
        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results[0].succeeded)
        XCTAssertEqual(results[1].resultSets.first?.rows.first?.first ?? nil, "42")
        XCTAssertNotNil(results[2].error)
        XCTAssertTrue(results[3].skipped)
    }

    // MARK: - Open transaction on close (round 21, #57)

    /// A MySQL tab's open transaction is found with no round trip and can be ended from the alert.
    func testOpenTransactionIsFoundAndEnded() async throws {
        let config = try await loadConfig()
        let connected = try await connect(config: config)
        let session = try XCTUnwrap(connected as? MySQLSession)
        defer { Task { @MainActor in await session.close() } }

        let none = await session.openTransactions(startedAt: nil)
        XCTAssertTrue(none.isEmpty)
        _ = try await session.simpleQuery("START TRANSACTION")
        let open = await session.openTransactions(startedAt: nil)
        XCTAssertEqual(open.count, 1)
        XCTAssertEqual(open.first?.failed, false)
        try await session.endTransactions(commit: false)
        let after = await session.openTransactions(startedAt: nil)
        XCTAssertTrue(after.isEmpty)
    }
}

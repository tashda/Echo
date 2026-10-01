import XCTest
import ServerLabClient
@testable import Echo

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
        let server = try await LabSharedServers.serverForSuite(LabRecipes.mysql)
        return MySQLConfig(host: server.host, port: server.port, database: "mysql",
                           username: server.username, password: server.password)
    }

    private func connect(config: MySQLConfig) async throws -> DatabaseSession {
        let factory = MySQLNIOFactory()
        return try await factory.connect(
            host: config.host,
            port: config.port,
            database: config.database,
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(
                username: config.username,
                password: config.password
            )
        )
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

        let databases = try await session.listDatabases()
        XCTAssertFalse(databases.isEmpty)
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
}

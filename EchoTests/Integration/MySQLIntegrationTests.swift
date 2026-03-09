import XCTest
@testable import Echo

final class MySQLIntegrationTests: XCTestCase {
    private struct MySQLConfig {
        let host: String
        let port: Int
        let database: String
        let username: String
        let password: String
    }

    private func loadConfig() throws -> MySQLConfig {
        let env = ProcessInfo.processInfo.environment
        guard
            let host = env["TEST_MYSQL_HOST"],
            let portStr = env["TEST_MYSQL_PORT"], let port = Int(portStr),
            let database = env["TEST_MYSQL_DATABASE"],
            let username = env["TEST_MYSQL_USER"],
            let password = env["TEST_MYSQL_PASSWORD"]
        else {
            throw XCTSkip("MySQL integration test env vars not set (TEST_MYSQL_HOST, TEST_MYSQL_PORT, TEST_MYSQL_DATABASE, TEST_MYSQL_USER, TEST_MYSQL_PASSWORD)")
        }
        return MySQLConfig(host: host, port: port, database: database, username: username, password: password)
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
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { await session.close() } }

        let result = try await session.simpleQuery("SELECT 1 AS value")
        XCTAssertEqual(result.columns.count, 1)
        XCTAssertEqual(result.rows.count, 1)
    }

    // MARK: - Schema Discovery

    func testListDatabases() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { await session.close() } }

        let databases = try await session.listDatabases()
        XCTAssertFalse(databases.isEmpty)
    }

    func testListTablesAndViews() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { await session.close() } }

        let objects = try await session.listTablesAndViews(schema: nil)
        XCTAssertNotNil(objects)
    }

    // MARK: - Query With Paging

    func testQueryWithPaging() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { await session.close() } }

        let result = try await session.queryWithPaging(
            "SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3",
            limit: 2,
            offset: 0
        )
        XCTAssertEqual(result.rows.count, 2)
    }
}

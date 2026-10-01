import XCTest
import ServerLabClient
@testable import Echo

@MainActor
final class PostgresIntegrationTests: XCTestCase {
    private struct PGConfig {
        let host: String
        let port: Int
        let database: String
        let username: String
        let password: String
    }

    /// The lab Postgres the suites share (`LabSharedServers`).
    private func loadConfig() async throws -> PGConfig {
        let server = try await LabSharedServers.serverForSuite(LabRecipes.postgres)
        return PGConfig(host: server.host, port: server.port, database: "postgres",
                        username: server.username, password: server.password)
    }

    private func connect(config: PGConfig) async throws -> DatabaseSession {
        let factory = PostgresNIOFactory()
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
        XCTAssertEqual(result.columns[0].name, "value")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0][0], "1")
    }

    // MARK: - Schema Discovery

    func testListDatabases() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let databases = try await session.listDatabases()
        XCTAssertFalse(databases.isEmpty, "Should list at least one database")
    }

    func testListSchemas() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let schemas = try await session.listSchemas()
        XCTAssertTrue(schemas.contains("public"), "Should contain 'public' schema")
    }

    func testListTablesAndViews() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let objects = try await session.listTablesAndViews(schema: "public")
        // May be empty in a fresh database, but should not throw
        XCTAssertNotNil(objects)
    }

    // MARK: - Query With Paging

    func testQueryWithPaging() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let result = try await session.queryWithPaging(
            "SELECT generate_series(1, 100) AS n",
            limit: 10,
            offset: 0
        )
        XCTAssertEqual(result.rows.count, 10)
    }

    // MARK: - Execute Update

    func testExecuteUpdateDDL() async throws {
        let config = try await loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let tableName = "echo_test_\(UUID().uuidString.prefix(8).lowercased())"
        _ = try await session.executeUpdate("CREATE TEMP TABLE \(tableName) (id serial PRIMARY KEY, name text)")
        let affected = try await session.executeUpdate("INSERT INTO \(tableName) (name) VALUES ('Alice'), ('Bob')")
        XCTAssertEqual(affected, 2)

        _ = try await session.executeUpdate("DROP TABLE \(tableName)")
    }
}

import XCTest
@testable import Echo

final class MSSQLIntegrationTests: XCTestCase {
    private struct MSSQLConfig {
        let host: String
        let port: Int
        let database: String
        let username: String
        let password: String
        let useTLS: Bool
    }

    private func loadConfig() throws -> MSSQLConfig {
        var env = ProcessInfo.processInfo.environment

        // Also check for .env file at project root
        if env["MSSQL_HOST"] == nil {
            let projectRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let envFilePath = projectRoot.appendingPathComponent("mssql.env").path
            if let contents = try? String(contentsOfFile: envFilePath) {
                for line in contents.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                    let parts = trimmed.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {
                        let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if env[key] == nil { env[key] = value }
                    }
                }
            }
        }

        guard
            let host = env["MSSQL_HOST"],
            let portStr = env["MSSQL_PORT"], let port = Int(portStr),
            let username = env["MSSQL_USERNAME"],
            let password = env["MSSQL_PASSWORD"]
        else {
            throw XCTSkip("MSSQL integration test env vars not set (MSSQL_HOST, MSSQL_PORT, MSSQL_USERNAME, MSSQL_PASSWORD)")
        }

        let database = env["MSSQL_DATABASE"] ?? "master"
        let useTLS = env["MSSQL_ENABLE_TLS"]?.lowercased() == "true"

        return MSSQLConfig(host: host, port: port, database: database, username: username, password: password, useTLS: useTLS)
    }

    private func connect(config: MSSQLConfig) async throws -> DatabaseSession {
        let factory = MSSQLNIOFactory()
        return try await factory.connect(
            host: config.host,
            port: config.port,
            database: config.database,
            tls: config.useTLS,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
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
        XCTAssertEqual(result.rows[0][0], "1")
    }

    // MARK: - Schema Discovery

    func testListDatabases() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { await session.close() } }

        let databases = try await session.listDatabases()
        XCTAssertFalse(databases.isEmpty)
        XCTAssertTrue(databases.contains("master"))
    }

    func testListSchemas() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { await session.close() } }

        let schemas = try await session.listSchemas()
        XCTAssertTrue(schemas.contains("dbo"))
    }

    func testListTablesAndViews() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { await session.close() } }

        let objects = try await session.listTablesAndViews(schema: "dbo")
        XCTAssertNotNil(objects)
    }

    // MARK: - Table Structure

    func testGetTableStructureDetails() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { await session.close() } }

        // Create a temp table to test
        let tableName = "##echo_test_\(UUID().uuidString.prefix(8).lowercased())"
        _ = try await session.executeUpdate("CREATE TABLE \(tableName) (id INT PRIMARY KEY, name NVARCHAR(100))")
        defer { Task { try? await session.executeUpdate("DROP TABLE \(tableName)") } }

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertGreaterThanOrEqual(details.columns.count, 2)
    }
}

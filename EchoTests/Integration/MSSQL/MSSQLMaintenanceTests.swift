import Testing
import Foundation
@testable import Echo

@Suite("MSSQL Maintenance Integration Tests")
struct MSSQLMaintenanceTests {
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

        if env["MSSQL_HOST"] == nil {
            let projectRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let envFilePath = projectRoot.appendingPathComponent(".env").path
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
            throw SettlementError.skip("MSSQL integration test env vars not set (MSSQL_HOST, MSSQL_PORT, MSSQL_USERNAME, MSSQL_PASSWORD)")
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

    @Test("Test list fragmented indexes")
    func testListFragmentedIndexes() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        // Create a table and index to ensure we have something to list
        let tableName = "MaintenanceTest_\(UUID().uuidString.prefix(8))"
        _ = try await session.simpleQuery("CREATE TABLE \(tableName) (id INT PRIMARY KEY, val VARCHAR(MAX))")
        _ = try await session.simpleQuery("CREATE INDEX IX_\(tableName) ON \(tableName)(val)")
        defer { _ = try? Task { try await session.simpleQuery("DROP TABLE \(tableName)") } }

        // Fragmentation might be 0 for a new table, but the query should still succeed
        let fragmented = try await session.listFragmentedIndexes()
        #expect(fragmented != nil)
    }

    @Test("Test database health stats")
    func testGetDatabaseHealth() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let health = try await session.getDatabaseHealth()
        #expect(health.sizeMB > 0)
        #expect(!health.recoveryModel.isEmpty)
        #expect(!health.status.isEmpty)
    }

    @Test("Test backup history retrieval")
    func testGetBackupHistory() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        let history = try await session.getBackupHistory(limit: 5)
        #expect(history != nil)
    }

    @Test("Test integrity check execution")
    func testCheckDatabaseIntegrity() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        try await session.checkDatabaseIntegrity()
    }

    @Test("Test database shrink execution")
    func testShrinkDatabase() async throws {
        let config = try loadConfig()
        let session = try await connect(config: config)
        defer { Task { @MainActor in await session.close() } }

        try await session.shrinkDatabase()
    }
}

enum SettlementError: Error {
    case skip(String)
}

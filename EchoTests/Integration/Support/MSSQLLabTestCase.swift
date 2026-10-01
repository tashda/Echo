import XCTest
import SQLServerKit
import ServerLabClient
import Synchronization
@testable import Echo

/// Base class for the SQL Server suites: every test gets a `DatabaseSession` on a lab server
/// started from `recipe`, shared by all suites of the test run (`LabSharedServers`). Runs only
/// with `SERVERLAB_INTEGRATION=1` (the EchoTests plan); skipped otherwise.
class MSSQLLabTestCase: XCTestCase {
    /// The recipe of the shared server. A suite that needs other content overrides it.
    class var recipe: String { "mssql-2022-agent" }

    private(set) var server: LabServer!
    private(set) var session: DatabaseSession!

    var host: String { server.host }
    var port: Int { server.port }
    var username: String { server.username }
    var password: String { server.password }

    /// Access the underlying SQLServerClient for typed API calls.
    var sqlserverClient: SQLServerClient {
        (session as! SQLServerSessionAdapter).client
    }

    // MARK: - Per-test Setup

    override func setUp() async throws {
        try await super.setUp()
        // Prevent hanging tests from blocking the entire CI suite.
        executionTimeAllowance = 60
        guard labIntegrationEnabled else { throw XCTSkip("\(labIntegrationNote)") }
        server = try await LabSharedServers.shared.server(for: Self.recipe)
        session = try await createSession()
    }

    override func tearDown() async throws {
        if let session {
            await session.close()
        }
        session = nil
        try await super.tearDown()
    }

    // MARK: - Session Factory

    func createSession(database: String? = nil) async throws -> DatabaseSession {
        try await MSSQLNIOFactory().connect(
            host: host,
            port: port,
            database: database,
            tls: true,
            trustServerCertificate: true,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: username,
                password: password
            ),
            connectTimeoutSeconds: 30
        )
    }

    // MARK: - Compatibility Level

    /// The shared server's compatibility level, once read.
    private static let cachedCompatLevel = Mutex<Int?>(nil)

    /// Returns the current database's compatibility level.
    func compatLevel() async throws -> Int {
        if let cached = Self.cachedCompatLevel.withLock({ $0 }) { return cached }
        let result = try await session.simpleQuery(
            "SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME()"
        )
        let levelStr = result.rows.first?.first.flatMap({ $0 }) ?? "0"
        let level = Int(levelStr) ?? 0
        Self.cachedCompatLevel.withLock { $0 = level }
        return level
    }

    /// Skips the test if the server's compat level is below the requirement.
    ///
    /// Common compat levels:
    /// - 100 = SQL Server 2008
    /// - 110 = SQL Server 2012
    /// - 120 = SQL Server 2014
    /// - 130 = SQL Server 2016
    /// - 140 = SQL Server 2017
    /// - 150 = SQL Server 2019
    /// - 160 = SQL Server 2022
    func requireCompatLevel(_ minimum: Int, feature: String = "") async throws {
        let level = try await compatLevel()
        if level < minimum {
            let desc = feature.isEmpty ? "" : " (\(feature))"
            throw XCTSkip("Requires compat level \(minimum)+\(desc), server is at \(level)")
        }
    }

    // MARK: - Test Helpers

    /// Execute a SQL statement and return the result set.
    func query(_ sql: String) async throws -> QueryResultSet {
        try await session.simpleQuery(sql)
    }

    /// Execute a SQL update and return affected row count.
    @discardableResult
    func execute(_ sql: String) async throws -> Int {
        try await session.executeUpdate(sql)
    }

    /// Generate a unique table name to avoid test collisions.
    func uniqueTableName(prefix: String = "echo_test") -> String {
        "\(prefix)_\(UUID().uuidString.prefix(8).lowercased())"
    }

    /// Schedule SQL cleanup to run after the test completes.
    /// Use this instead of `defer { Task { ... } }` which causes Swift 6 sending errors.
    func cleanupSQL(_ statements: String...) {
        let session = self.session!
        addTeardownBlock {
            for sql in statements {
                _ = try? await session.executeUpdate(sql)
            }
        }
    }

    /// Create a temporary table and run a closure, then clean up.
    func withTempTable(
        name: String? = nil,
        columns: String = "id INT PRIMARY KEY, name NVARCHAR(100), value INT",
        body: (String) async throws -> Void
    ) async throws {
        let tableName = name ?? uniqueTableName()
        try await execute("CREATE TABLE [\(tableName)] (\(columns))")
        do {
            try await body(tableName)
        } catch {
            try? await execute("DROP TABLE IF EXISTS [\(tableName)]")
            throw error
        }
        try? await execute("DROP TABLE IF EXISTS [\(tableName)]")
    }
}

import XCTest
import SQLServerKit
import ServerLabClient
import Synchronization
@testable import Echo

/// Base class for the SQL Server suites: every test gets a `DatabaseSession` on a lab server
/// started from `recipe`, shared by all suites of the test run (`LabSharedServers`). Each suite
/// works in a database of its own (`scratchDatabase`, made through sqlserver-nio), where sessions
/// open unless a test names another database; the server is removed after the run, so nothing in
/// it needs dropping. Runs only with `SERVERLAB_INTEGRATION=1` (the EchoTests plan).
class MSSQLLabTestCase: XCTestCase {
    /// The recipe of the shared server. A suite that needs other content overrides it.
    class var recipe: String { LabRecipes.sqlServer }

    private(set) var server: LabServer!
    private(set) var session: DatabaseSession!
    /// This suite's own database on the shared server.
    private(set) var scratchDatabase: String!

    /// Scratch databases made so far, by suite and server.
    private static let scratchDatabases = Mutex<[String: String]>([:])

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
        scratchDatabase = try await makeScratchDatabaseIfNeeded()
        session = try await createSession()
    }

    /// `echo_<suite>` on this server, made the first time one of the suite's tests runs.
    private func makeScratchDatabaseIfNeeded() async throws -> String {
        let key = "\(Self.self)|\(server.containerName)"
        if let existing = Self.scratchDatabases.withLock({ $0[key] }) { return existing }
        let name = "echo_\(String(describing: Self.self).lowercased())"
        let master = try await createSession(database: "master")
        do {
            let admin = (master as! SQLServerSessionAdapter).client.admin
            if try await !(master.listDatabases()).contains(name) {
                try await admin.createDatabase(name: name)
            }
            await master.close()
        } catch {
            await master.close()
            throw error
        }
        Self.scratchDatabases.withLock { $0[key] = name }
        return name
    }

    override func tearDown() async throws {
        if let session {
            await session.close()
        }
        session = nil
        try await super.tearDown()
    }

    // MARK: - Session Factory

    /// A session on `database`, else on the suite's scratch database.
    func createSession(database: String? = nil) async throws -> DatabaseSession {
        try await MSSQLNIOFactory().connect(
            host: host,
            port: port,
            database: database ?? scratchDatabase,
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
}

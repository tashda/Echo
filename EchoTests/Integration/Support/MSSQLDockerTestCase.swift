import XCTest
import SQLServerKit
@testable import Echo

/// Base class for SQL Server integration tests using Docker.
///
/// Automatically starts a SQL Server Docker container (with compat level support)
/// and provides a `DatabaseSession` for tests. Skips if Docker is unavailable or
/// `USE_DOCKER` is not set.
class MSSQLDockerTestCase: XCTestCase {
    static let dockerManager = EchoDockerManager()
    nonisolated(unsafe) static var isDockerReady = false
    nonisolated(unsafe) static var dockerError: Error?

    /// The port for the MSSQL container.
    static var port: Int {
        Int(echoTestEnv("ECHO_MSSQL_PORT") ?? "14332") ?? 14332
    }

    /// The SQL Server Docker image version.
    static var imageVersion: String {
        echoTestEnv("ECHO_MSSQL_VERSION") ?? "2022-latest"
    }

    /// Optional compatibility level override (e.g. "100" for 2008 R2 behavior).
    static var compatLevel: String? {
        echoTestEnv("ECHO_MSSQL_COMPAT")
    }

    static let username = "sa"
    static let password = "Password123!"
    static var requiresValidatedFixtures: Bool {
        echoTestEnvFlag("ECHO_REQUIRE_VALIDATED_FIXTURES")
    }

    private(set) var session: DatabaseSession!

    /// Access the underlying SQLServerClient for typed API calls.
    var sqlserverClient: SQLServerClient {
        (session as! SQLServerSessionAdapter).client
    }

    // MARK: - Docker Setup (once per class)

    override class func setUp() {
        super.setUp()
        guard echoTestEnvFlag("USE_DOCKER") else { return }

        if echoTestEnvFlag("ECHO_USE_PACKAGE_FIXTURES") || echoTestEnvFlag("ECHO_MSSQL_FIXTURE_VALIDATED") {
            isDockerReady = true
            dockerError = nil
            return
        }

        let resolvedImage = resolvedImageName(for: imageVersion)

        let config = EchoDockerManager.ContainerConfig(
            engine: .mssql,
            imageTag: resolvedImage,
            port: port,
            environmentVariables: [
                "ACCEPT_EULA": "Y",
                "MSSQL_SA_PASSWORD": password,
                "MSSQL_AGENT_ENABLED": "true"
            ],
            containerNamePrefix: "echo-test-mssql",
            readinessCheck: { dockerPath, containerId in
                mssqlReadinessCheck(dockerPath: dockerPath, containerId: containerId)
            }
        )

        do {
            try dockerManager.startIfNeeded(config: config)
            if let level = effectiveCompatLevel {
                try setCompatibilityLevel(level)
            }
            isDockerReady = true
        } catch {
            dockerError = error
            print("⚠️ MSSQL Docker setup failed: \(error)")
        }
    }

    // MARK: - Per-test Setup

    override func setUp() async throws {
        try await super.setUp()
        guard echoTestEnvFlag("USE_DOCKER") else {
            try Self.failIfFixturesRequired("USE_DOCKER not set for MSSQL integration tests")
            throw XCTSkip("USE_DOCKER not set — skipping MSSQL integration tests")
        }
        if echoTestEnvFlag("ECHO_USE_PACKAGE_FIXTURES") || echoTestEnvFlag("ECHO_MSSQL_FIXTURE_VALIDATED") {
            session = try await createSession()
            return
        }
        if let error = Self.dockerError {
            try Self.failIfFixturesRequired("MSSQL Docker setup failed: \(error)")
            throw XCTSkip("Docker setup failed: \(error)")
        }
        guard Self.isDockerReady else {
            try Self.failIfFixturesRequired("MSSQL Docker fixture was not ready")
            throw XCTSkip("Docker not ready")
        }

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
        let factory = MSSQLNIOFactory()
        return try await factory.connect(
            host: "127.0.0.1",
            port: Self.port,
            database: database,
            tls: false,
            trustServerCertificate: true,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: Self.username,
                password: Self.password
            ),
            connectTimeoutSeconds: 15
        )
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

    // MARK: - Compat Level & Image Resolution

    private static var effectiveCompatLevel: Int? {
        if let explicit = compatLevel, let level = Int(explicit) {
            return level
        }
        return inferredCompatLevel(for: imageVersion)
    }

    private static func inferredCompatLevel(for ver: String) -> Int? {
        if ver.contains("2008") { return 100 }
        if ver.contains("2012") { return 110 }
        if ver.contains("2014") { return 120 }
        if ver.contains("2016") { return 130 }
        return nil
    }

    private static func resolvedImageName(for ver: String) -> String {
        if ver.contains("/") { return ver }
        if inferredCompatLevel(for: ver) != nil {
            return "mcr.microsoft.com/mssql/server:2017-latest"
        }
        return "mcr.microsoft.com/mssql/server:\(ver)"
    }

    private static func setCompatibilityLevel(_ level: Int) throws {
        print("⚙️ Setting compatibility level to \(level)...")
        let sqlcmdPath = detectSQLCmdPath()
        var args = [sqlcmdPath, "-S", "localhost", "-U", username, "-P", password, "-b"]
        if sqlcmdPath.contains("mssql-tools18") { args.append("-C") }
        args += ["-Q", "ALTER DATABASE [master] SET COMPATIBILITY_LEVEL = \(level);"]
        let (_, exitCode) = try dockerManager.exec(arguments: ["/bin/bash", "-lc", args.joined(separator: " ")])
        if exitCode != 0 {
            print("⚠️ Failed to set compat level \(level)")
        }
    }

    private static func detectSQLCmdPath() -> String {
        let (output, _) = (try? dockerManager.exec(arguments: [
            "/bin/bash", "-lc",
            "if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then echo /opt/mssql-tools18/bin/sqlcmd; elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then echo /opt/mssql-tools/bin/sqlcmd; fi"
        ])) ?? ("", 1)
        return output.isEmpty ? "/opt/mssql-tools/bin/sqlcmd" : output
    }

    private static func mssqlReadinessCheck(dockerPath: String, containerId: String) -> Bool {
        let process = EchoDockerManager.createProcess(executable: dockerPath, arguments: [
            "exec", containerId, "/bin/bash", "-lc",
            "if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then /opt/mssql-tools18/bin/sqlcmd -S localhost -U \(username) -P '\(password)' -C -Q 'SELECT 1'; else /opt/mssql-tools/bin/sqlcmd -S localhost -U \(username) -P '\(password)' -Q 'SELECT 1'; fi"
        ])
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private static func failIfFixturesRequired(_ message: String) throws {
        guard requiresValidatedFixtures else { return }
        throw NSError(
            domain: "Echo.IntegrationFixtures",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

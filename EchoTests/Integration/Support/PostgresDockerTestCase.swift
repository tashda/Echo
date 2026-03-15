import XCTest
@testable import Echo

/// Base class for PostgreSQL integration tests using Docker.
///
/// Automatically starts a PostgreSQL Docker container and provides a
/// `DatabaseSession` for tests. Skips if Docker is unavailable or
/// `USE_DOCKER` is not set.
class PostgresDockerTestCase: XCTestCase {
    static let dockerManager = EchoDockerManager()
    nonisolated(unsafe) static var isDockerReady = false
    nonisolated(unsafe) static var dockerError: Error?
    nonisolated(unsafe) static var sampleDataLoaded = false

    /// The port for the Postgres container.
    static var port: Int {
        Int(echoTestEnv("ECHO_PG_PORT") ?? "54322") ?? 54322
    }

    /// The PostgreSQL Docker image version.
    static var imageVersion: String {
        echoTestEnv("ECHO_PG_VERSION") ?? "16"
    }

    static let username = "postgres"
    static let password = "postgres"
    static let database = "postgres"

    private(set) var session: DatabaseSession!

    // MARK: - Docker Setup (once per class)

    override class func setUp() {
        super.setUp()
        guard echoTestEnvFlag("USE_DOCKER") else { return }

        let config = EchoDockerManager.ContainerConfig(
            engine: .postgres,
            imageTag: "postgres:\(imageVersion)",
            port: port,
            environmentVariables: [
                "POSTGRES_PASSWORD": password
            ],
            containerNamePrefix: "echo-test-pg",
            readinessCheck: { dockerPath, containerId in
                pgReadinessCheck(dockerPath: dockerPath, containerId: containerId)
            }
        )

        do {
            try dockerManager.startIfNeeded(config: config)
            Thread.sleep(forTimeInterval: 2.0) // stabilization
            if !sampleDataLoaded {
                try loadSampleData()
                sampleDataLoaded = true
            }
            isDockerReady = true
        } catch {
            dockerError = error
            print("⚠️ Postgres Docker setup failed: \(error)")
        }
    }

    // MARK: - Per-test Setup

    override func setUp() async throws {
        try await super.setUp()
        guard echoTestEnvFlag("USE_DOCKER") else {
            throw XCTSkip("USE_DOCKER not set — skipping Postgres integration tests")
        }
        if let error = Self.dockerError {
            throw XCTSkip("Docker setup failed: \(error)")
        }
        guard Self.isDockerReady else {
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
        let factory = PostgresNIOFactory()
        return try await factory.connect(
            host: "127.0.0.1",
            port: Self.port,
            database: database ?? Self.database,
            tls: false,
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

    /// Generate a unique name to avoid test collisions.
    func uniqueName(prefix: String = "echo_test") -> String {
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
        schema: String = "public",
        name: String? = nil,
        columns: String = "id SERIAL PRIMARY KEY, name TEXT, value INTEGER",
        body: (String) async throws -> Void
    ) async throws {
        let tableName = name ?? uniqueName()
        try await execute("CREATE TABLE \(schema).\(tableName) (\(columns))")
        do {
            try await body(tableName)
        } catch {
            try? await execute("DROP TABLE IF EXISTS \(schema).\(tableName)")
            throw error
        }
        try? await execute("DROP TABLE IF EXISTS \(schema).\(tableName)")
    }

    // MARK: - Sample Data

    private static func loadSampleData() throws {
        let fm = FileManager.default
        let possiblePaths = [
            fm.currentDirectoryPath + "/EchoTests/Integration/Support/SampleData/PostgresSampleData.sql",
            Bundle(for: PostgresDockerTestCase.self).path(forResource: "PostgresSampleData", ofType: "sql"),
            "/Users/k/Development/Echo/EchoTests/Integration/Support/SampleData/PostgresSampleData.sql"
        ].compactMap { $0 }

        for path in possiblePaths {
            guard fm.fileExists(atPath: path) else { continue }
            print("📄 Loading PG sample data from \(path)")
            let sql = try String(contentsOfFile: path, encoding: .utf8)
            let (_, exitCode) = try dockerManager.exec(
                arguments: ["psql", "-U", username, "-d", database],
                input: sql
            )
            if exitCode != 0 {
                print("⚠️ PG sample data load had errors (exit \(exitCode))")
            } else {
                print("✅ PG sample data loaded")
            }
            return
        }
        print("⚠️ PostgresSampleData.sql not found — tests will create their own fixtures")
    }

    private static func pgReadinessCheck(dockerPath: String, containerId: String) -> Bool {
        let process = EchoDockerManager.createProcess(executable: dockerPath, arguments: [
            "exec", containerId, "pg_isready", "-U", username
        ])
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

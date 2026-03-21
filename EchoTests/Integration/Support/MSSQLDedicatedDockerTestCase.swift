import XCTest
import SQLServerKit
@testable import Echo

/// Base class for MSSQL integration tests that need a dedicated query session.
///
/// This mirrors how Echo actually handles query tabs: each tab gets its own
/// `MSSQLDedicatedQuerySession` backed by a physical `SQLServerConnection`,
/// while metadata/admin operations are delegated to a shared pooled session.
///
/// Use this base class for tests that exercise query execution, streaming,
/// transactions, temp tables, or any behavior that depends on session-local state.
class MSSQLDedicatedDockerTestCase: MSSQLDockerTestCase {
    private(set) var dedicatedSession: MSSQLDedicatedQuerySession!

    /// The pooled metadata session (inherited from MSSQLDockerTestCase as `session`).
    var metadataAdapter: SQLServerSessionAdapter {
        session as! SQLServerSessionAdapter
    }

    override func setUp() async throws {
        try await super.setUp()
        dedicatedSession = try await makeDedicatedSession()
    }

    override func tearDown() async throws {
        if let dedicatedSession {
            await dedicatedSession.close()
        }
        dedicatedSession = nil
        try await super.tearDown()
    }

    /// Create a new dedicated query session (for multi-tab tests).
    func makeDedicatedSession(database: String? = nil) async throws -> MSSQLDedicatedQuerySession {
        let configuration = try MSSQLNIOFactory.makeConnectionConfiguration(
            host: "127.0.0.1",
            port: Self.port,
            database: database,
            tls: false,
            trustServerCertificate: true,
            sslRootCertPath: nil,
            mssqlEncryptionMode: .optional,
            readOnlyIntent: false,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: Self.username,
                password: Self.password
            ),
            connectTimeoutSeconds: 15
        )
        let connection = try await SQLServerConnection.connect(
            configuration: configuration
        )
        return MSSQLDedicatedQuerySession(
            connection: connection,
            configuration: configuration,
            metadataSession: metadataAdapter
        )
    }

    /// Execute a query on the dedicated session.
    func dedicatedQuery(_ sql: String) async throws -> QueryResultSet {
        try await dedicatedSession.simpleQuery(sql)
    }

    /// Execute an update on the dedicated session.
    @discardableResult
    func dedicatedExecute(_ sql: String) async throws -> Int {
        try await dedicatedSession.executeUpdate(sql)
    }
}

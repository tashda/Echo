import XCTest
import SQLServerKit
@testable import Echo

/// Round 22 cancel behaviour of a query tab's dedicated SQL Server session, against a real server:
/// a cancel keeps the session and its #temp tables (CL1), and a cancel inside a transaction leaves
/// no transaction open because XACT_ABORT is on (XA1).
final class MSSQLDedicatedSessionCancelTests: MSSQLDockerTestCase {
    private func makeDedicatedSession() async throws -> MSSQLDedicatedQuerySession {
        let configuration = try MSSQLNIOFactory.makeConnectionConfiguration(
            host: "127.0.0.1",
            port: Self.port,
            database: "master",
            tls: false,
            trustServerCertificate: true,
            sslRootCertPath: nil,
            mssqlEncryptionMode: .optional,
            hostNameInCertificate: nil,
            readOnlyIntent: false,
            authentication: .init(method: .sqlPassword, username: Self.username, password: Self.password),
            connectTimeoutSeconds: 15
        )
        let connection = try await SQLServerConnection.connect(configuration: configuration)
        let metadata = try XCTUnwrap(session as? SQLServerSessionAdapter)
        return MSSQLDedicatedQuerySession(connection: connection, configuration: configuration, metadataSession: metadata)
    }

    /// Starts a long statement, cancels it after half a second and waits for the task to end.
    private func runAndCancel(_ sql: String, on dedicated: MSSQLDedicatedQuerySession) async throws {
        let task = Task { try await dedicated.simpleQuery(sql) }
        try await Task.sleep(for: .milliseconds(500))
        let started = ContinuousClock.now
        task.cancel()
        _ = try? await task.value
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(10), "The cancel must end the statement promptly")
    }

    func testCancelKeepsTheSessionAndItsTempTables() async throws {
        let dedicated = try await makeDedicatedSession()
        defer { Task { await dedicated.close() } }
        _ = try await dedicated.simpleQuery("CREATE TABLE #kept (id int); INSERT INTO #kept VALUES (1);")
        let spidBefore = try await dedicated.simpleQuery("SELECT @@SPID AS spid;").rows.first?.first ?? nil

        try await runAndCancel("WAITFOR DELAY '00:00:30';", on: dedicated)

        let rows = try await dedicated.simpleQuery("SELECT COUNT(*) AS n FROM #kept;").rows
        XCTAssertEqual(rows.first?.first, "1", "#temp tables survive a cancel")
        let spidAfter = try await dedicated.simpleQuery("SELECT @@SPID AS spid;").rows.first?.first ?? nil
        XCTAssertEqual(spidAfter, spidBefore, "A cancel keeps the same session")
    }

    func testCancelInsideATransactionRollsItBack() async throws {
        let dedicated = try await makeDedicatedSession()
        defer { Task { await dedicated.close() } }
        _ = try await dedicated.simpleQuery("CREATE TABLE #orders (id int);")
        _ = try await dedicated.simpleQuery("BEGIN TRANSACTION; INSERT INTO #orders VALUES (1);")
        XCTAssertTrue(dedicated.isInTransaction)

        try await runAndCancel("WAITFOR DELAY '00:00:30';", on: dedicated)

        XCTAssertFalse(dedicated.isInTransaction, "XACT_ABORT ON: the cancel rolls the transaction back")
        let rows = try await dedicated.simpleQuery("SELECT COUNT(*) AS n, @@TRANCOUNT AS trancount FROM #orders;").rows
        XCTAssertEqual(rows.first, ["0", "0"], "The insert was rolled back and no transaction is open")
    }
}

import XCTest
import SQLServerKit
@testable import Echo

/// Round 22 errors on a query tab's dedicated SQL Server session, against a real server: a failed
/// batch carries every message in order with number, severity, line and procedure (EM1, LL1), and
/// a severity 20 error takes the lost-connection path, after which the next run reconnects (FE1).
final class MSSQLDedicatedSessionErrorTests: MSSQLDockerTestCase {
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

    /// The streaming path a query tab uses (a progress handler is set).
    private func run(_ sql: String, on dedicated: MSSQLDedicatedQuerySession) async throws -> QueryResultSet {
        try await dedicated.simpleQuery(sql, progressHandler: { _ in })
    }

    func testFailedBatchCarriesEveryMessageWithItsLine() async throws {
        let dedicated = try await makeDedicatedSession()
        defer { Task { await dedicated.close() } }
        let sql = "PRINT 'loading orders';\nSELECT 1 AS ok;\nSELECT * FROM dbo.table_that_does_not_exist;"
        do {
            _ = try await run(sql, on: dedicated)
            XCTFail("The batch should fail")
        } catch {
            let messages = SQLServerFailure.serverMessages(of: error)
            XCTAssertEqual(messages.first?.message, "loading orders", "PRINT output before the error is kept")
            let failure = try XCTUnwrap(messages.last)
            XCTAssertEqual(failure.kind, .error)
            XCTAssertEqual(failure.number, 208)
            XCTAssertEqual(failure.lineNumber, 3)
            XCTAssertEqual(failure.ssmsHeader, "Msg 208, Level 16, State 1, Line 3")
            XCTAssertFalse(SQLServerFailure.isConnectionLost(error))
        }
        let after = try await run("SELECT 7 AS v;", on: dedicated)
        XCTAssertEqual(after.rows.first?.first, "7", "An ordinary error keeps the session")
    }

    func testErrorInsideAProcedureNamesIt() async throws {
        let dedicated = try await makeDedicatedSession()
        defer { Task { await dedicated.close() } }
        _ = try await run("CREATE PROCEDURE #load_orders AS\nBEGIN\n  RAISERROR('boom', 16, 1);\nEND", on: dedicated)
        do {
            _ = try await run("EXEC #load_orders;", on: dedicated)
            XCTFail("The procedure should fail")
        } catch {
            let failure = try XCTUnwrap(SQLServerFailure.serverMessages(of: error).last)
            XCTAssertEqual(failure.number, 50000)
            XCTAssertEqual(failure.lineNumber, 3)
            XCTAssertTrue(failure.procedureName?.hasPrefix("#load_orders") == true, "procedure: \(String(describing: failure.procedureName))")
        }
    }

    func testSeverityTwentyEndsTheSessionAndTheNextRunReconnects() async throws {
        let dedicated = try await makeDedicatedSession()
        defer { Task { await dedicated.close() } }
        do {
            _ = try await run("RAISERROR('fatal', 20, 1) WITH LOG;", on: dedicated)
            XCTFail("A severity 20 error should fail the run")
        } catch {
            XCTAssertTrue(SQLServerFailure.isConnectionLost(error), "FE1: got \(error)")
        }
        let after = try await run("SELECT 8 AS v;", on: dedicated)
        XCTAssertEqual(after.rows.first?.first, "8", "The next run uses a new session")
    }
}

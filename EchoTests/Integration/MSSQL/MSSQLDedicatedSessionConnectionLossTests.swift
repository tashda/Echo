import XCTest
import SQLServerKit
@testable import Echo

/// Round 22 LC4 (the PostgreSQL connection-lost decision, CW2 RC2 WD2) on a query tab's dedicated
/// SQL Server session, against a real server. The tab's session is killed from another connection.
final class MSSQLDedicatedSessionConnectionLossTests: MSSQLLabTestCase {
    private final class Drops: @unchecked Sendable {
        private let lock = NSLock()
        private var events: [(database: String, transactionLost: Bool, isReminder: Bool)] = []

        func record(_ database: String, _ transactionLost: Bool, _ isReminder: Bool) {
            lock.withLock { events.append((database, transactionLost, isReminder)) }
        }

        var all: [(database: String, transactionLost: Bool, isReminder: Bool)] { lock.withLock { events } }
    }

    private func makeDedicatedSession() async throws -> MSSQLDedicatedQuerySession {
        let configuration = try MSSQLNIOFactory.makeConnectionConfiguration(
            host: host,
            port: port,
            database: "master",
            tls: false,
            trustServerCertificate: true,
            sslRootCertPath: nil,
            mssqlEncryptionMode: .optional,
            hostNameInCertificate: nil,
            readOnlyIntent: false,
            authentication: .init(method: .sqlPassword, username: username, password: password),
            connectTimeoutSeconds: 15
        )
        let connection = try await SQLServerConnection.connect(configuration: configuration)
        let metadata = try XCTUnwrap(session as? SQLServerSessionAdapter)
        return MSSQLDedicatedQuerySession(connection: connection, configuration: configuration, metadataSession: metadata)
    }

    /// The session's SPID (for KILL) and its connection's unique id: SQL Server often hands a
    /// freed SPID to the next connection, so only the connection id proves a new session.
    private func identity(of dedicated: MSSQLDedicatedQuerySession) async throws -> (spid: String, connection: String) {
        let rows = try await dedicated.simpleQuery(
            "SELECT @@SPID AS spid, CONVERT(nvarchar(36), connection_id) AS id FROM sys.dm_exec_connections WHERE session_id = @@SPID;"
        ).rows
        let row = try XCTUnwrap(rows.first)
        return (try XCTUnwrap(row.first ?? nil), try XCTUnwrap(row.last ?? nil))
    }

    /// Kills the tab's session from the harness connection, as a DBA or a failover would.
    private func kill(_ spid: String) async throws {
        _ = try await session.simpleQuery("KILL \(spid);")
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() { try await Task.sleep(for: .milliseconds(100)) }
    }

    func testDropWithATransactionOpenIsToldAtOnceAndWaitsForReconnect() async throws {
        let dedicated = try await makeDedicatedSession()
        defer { Task { await dedicated.close() } }
        let drops = Drops()
        dedicated.setConnectionLostHandler { drops.record($0, $1, $2) }
        _ = try await dedicated.simpleQuery("CREATE TABLE #work (id int); BEGIN TRANSACTION; INSERT INTO #work VALUES (1);")
        let before = try await identity(of: dedicated)

        try await kill(before.spid)
        try await waitFor { !drops.all.isEmpty }
        let drop = try XCTUnwrap(drops.all.first, "CW2: the drop is told before any run")
        XCTAssertEqual(drop.database, "master")
        XCTAssertTrue(drop.transactionLost)
        XCTAssertFalse(drop.isReminder)
        XCTAssertTrue(dedicated.isAwaitingReconnect)

        do {
            _ = try await dedicated.simpleQuery("SELECT 1;")
            XCTFail("RC2: runs wait for Reconnect")
        } catch let error as MSSQLSessionError {
            XCTAssertEqual(error, .awaitingReconnect(database: "master"))
        }
        XCTAssertTrue(drops.all.last?.isReminder == true, "A refused run brings the notification back")

        try await dedicated.reconnect()
        XCTAssertFalse(dedicated.isAwaitingReconnect)
        let after = try await identity(of: dedicated)
        XCTAssertNotEqual(after.connection, before.connection, "Reconnect starts a new session")
        let temp = try await dedicated.simpleQuery("SELECT OBJECT_ID('tempdb..#work') AS id;").rows.first?.first ?? nil
        XCTAssertNil(temp, "The old session's temporary tables are gone")
    }

    func testIdleDropIsQuietAndTheNextRunReconnects() async throws {
        let dedicated = try await makeDedicatedSession()
        defer { Task { await dedicated.close() } }
        let drops = Drops()
        dedicated.setConnectionLostHandler { drops.record($0, $1, $2) }
        let before = try await identity(of: dedicated)

        try await kill(before.spid)
        try await waitFor { !drops.all.isEmpty }
        XCTAssertEqual(drops.all.count, 1)
        XCTAssertEqual(drops.all.first?.transactionLost, false)
        XCTAssertFalse(dedicated.isAwaitingReconnect)

        let after = try await identity(of: dedicated)
        XCTAssertNotEqual(after.connection, before.connection, "The next run reconnects by itself")
        XCTAssertEqual(drops.all.count, 1, "A quiet reconnect is not another drop")
    }

    func testClosingTheTabIsNotADrop() async throws {
        let dedicated = try await makeDedicatedSession()
        let drops = Drops()
        dedicated.setConnectionLostHandler { drops.record($0, $1, $2) }
        _ = try await dedicated.simpleQuery("SELECT 1;")
        await dedicated.close()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(drops.all.isEmpty)
    }

    func testForceStopClosesTheConnectionAndTheNextRunStartsANewSession() async throws {
        let dedicated = try await makeDedicatedSession()
        defer { Task { await dedicated.close() } }
        let drops = Drops()
        dedicated.setConnectionLostHandler { drops.record($0, $1, $2) }
        _ = try await dedicated.simpleQuery("BEGIN TRANSACTION;")
        let before = try await identity(of: dedicated)

        let running = Task { try await dedicated.simpleQuery("WAITFOR DELAY '00:00:30';") }
        try await Task.sleep(for: .milliseconds(500))
        let outcome = await dedicated.forceStopRunningQuery()
        _ = try? await running.value
        XCTAssertTrue(outcome.stopped)
        XCTAssertTrue(outcome.transactionWasOpen)

        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(drops.all.isEmpty, "Force Stop is the user's choice, not a drop")
        XCTAssertFalse(dedicated.isAwaitingReconnect)
        let after = try await identity(of: dedicated)
        XCTAssertNotEqual(after.connection, before.connection)
    }
}

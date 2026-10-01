import XCTest
import PostgresKit
import ServerLabClient
@testable import Echo

/// Round 21, connection lost (accepted): a query tab learns the moment its connection drops,
/// whether a transaction was lost, and after lost work runs wait for Reconnect.
///
/// Runs on the lab Postgres the suites share (`LabSharedServers`).
@MainActor
final class PostgresConnectionLossTests: XCTestCase {
    private var session: PostgresSession!

    private final class Drops: @unchecked Sendable {
        private let lock = NSLock()
        private var events: [(database: String, transactionLost: Bool, isReminder: Bool)] = []
        func record(_ event: (String, Bool, Bool)) { lock.withLock { events.append(event) } }
        var all: [(database: String, transactionLost: Bool, isReminder: Bool)] { lock.withLock { events } }
    }

    override func setUp() async throws {
        try await super.setUp()
        let server = try await labServer(LabRecipes.postgres)
        let base = try await PostgresNIOFactory().connect(
            host: server.host, port: server.port, database: "postgres", tls: false, tlsMode: .disable,
            authentication: DatabaseAuthenticationConfiguration(method: .sqlPassword, username: server.username, password: server.password)
        )
        session = (base as! PostgresSession).withPinnedQueries()
    }

    override func tearDown() async throws {
        await session?.close()
        try await super.tearDown()
    }

    private func run(_ sql: String) async throws -> QueryResultSet {
        try await session.simpleQuery(sql, executionMode: nil, progressHandler: { _ in })
    }

    private func installHandler() async -> Drops {
        let drops = Drops()
        await session.pinnedStore!.setConnectionLostHandler { drops.record(($0, $1, $2)) }
        return drops
    }

    /// Ends the tab's backend from a pooled connection, as a server restart or network drop would.
    private func terminateTabBackend() async throws {
        let pid = try await run("SELECT pg_backend_pid()").rows.first?.first.flatMap { $0 }
        _ = try await session.client.simpleQueryResult("SELECT pg_terminate_backend(\(pid!))")
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<50 where !condition() { try await Task.sleep(for: .milliseconds(100)) }
    }

    func testDropWithTransactionIsReportedAtOnceAndRunsWaitForReconnect() async throws {
        let drops = await installHandler()
        _ = try await run("BEGIN")
        _ = try await run("CREATE TEMP TABLE lost_work (id int)")
        let pid = try await run("SELECT pg_backend_pid()").rows.first?.first.flatMap { $0 }
        _ = try await session.client.simpleQueryResult("SELECT pg_terminate_backend(\(pid!))")

        try await waitFor { !drops.all.isEmpty }
        XCTAssertEqual(drops.all.count, 1, "reported the moment it drops, before any run")
        XCTAssertEqual(drops.all.first?.database, "postgres")
        XCTAssertEqual(drops.all.first?.transactionLost, true)
        XCTAssertEqual(drops.all.first?.isReminder, false)
        let awaiting = await session.pinnedStore!.isAwaitingReconnect()
        XCTAssertTrue(awaiting)

        for _ in 0..<2 {
            do {
                _ = try await run("SELECT 1")
                XCTFail("runs wait for Reconnect")
            } catch {
                XCTAssertTrue(error.localizedDescription.contains("Press Reconnect"), error.localizedDescription)
            }
        }
        XCTAssertEqual(drops.all.filter(\.isReminder).count, 2, "each blocked run brings the notification back")

        try await session.pinnedStore!.reconnect(database: "postgres")
        let after = try await run("SELECT pg_backend_pid()").rows.first?.first.flatMap { $0 }
        XCTAssertNotEqual(after, pid, "Reconnect opens a new backend")
        let stillAwaiting = await session.pinnedStore!.isAwaitingReconnect()
        XCTAssertFalse(stillAwaiting)
    }

    func testIdleDropIsReportedAndTheNextRunReconnects() async throws {
        let drops = await installHandler()
        try await terminateTabBackend()
        try await waitFor { !drops.all.isEmpty }
        XCTAssertEqual(drops.all.first?.transactionLost, false)
        let result = try await run("SELECT 1")
        XCTAssertEqual(result.rows.first?.first, "1", "nothing was lost, so the next run reconnects")
    }

    func testClosingTheTabIsNotADrop() async throws {
        let drops = await installHandler()
        _ = try await run("SELECT 1")
        await session.close()
        session = nil
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(drops.all.isEmpty)
    }
}

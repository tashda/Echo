import XCTest
import PostgresKit
import ServerLabClient
@testable import Echo

/// Round 21, cancelling a query (accepted): a cancel inside a transaction leaves it needing
/// ROLLBACK (TX1), and Force Stop closes the connection so the next run gets a new session (CS2).
///
/// Runs on the lab Postgres the suites share (`LabSharedServers`).
@MainActor
final class PostgresCancelTests: XCTestCase {
    private var session: PostgresSession!

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

    func testCancelInsideATransactionLeavesItNeedingRollback() async throws {
        _ = try await run("BEGIN")
        let session = self.session!
        let running = Task { try await session.simpleQuery("SELECT pg_sleep(10)", executionMode: nil, progressHandler: { _ in }) }
        try await Task.sleep(for: .milliseconds(600))
        let sent = await session.cancelRunningQuery()
        XCTAssertTrue(sent)
        _ = try? await running.value
        let status = await session.pinnedTransactionStatus()
        XCTAssertEqual(status, .failed)
        _ = try await run("ROLLBACK")
        let after = await session.pinnedTransactionStatus()
        XCTAssertEqual(after, .idle)
    }

    func testForceStopClosesTheConnectionAndTheNextRunGetsANewSession() async throws {
        let before = try await run("SELECT pg_backend_pid()").rows.first?.first ?? nil
        let session = self.session!
        let running = Task { try await session.simpleQuery("SELECT pg_sleep(10)", executionMode: nil, progressHandler: { _ in }) }
        try await Task.sleep(for: .milliseconds(600))
        let started = ContinuousClock.now
        let outcome = await session.forceStopRunningQuery()
        XCTAssertTrue(outcome.stopped)
        XCTAssertFalse(outcome.transactionWasOpen)
        _ = try? await running.value
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(5), "the statement ends at once, not after pg_sleep")
        let after = try await run("SELECT pg_backend_pid()").rows.first?.first ?? nil
        XCTAssertNotEqual(before, after)
    }
}

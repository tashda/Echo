import XCTest
import PostgresKit
import ServerLabClient
@testable import Echo

/// Round 21, timeouts (accepted): the tab's time limit stops a statement, Run Without Limit lifts
/// it (even a server limit), and a limit set on the server is read (SL1).
///
/// Runs on the lab Postgres the suites share (`LabSharedServers`).
@MainActor
final class PostgresQueryTimeLimitTests: XCTestCase {
    private var session: PostgresSession!
    private var store: PostgresPinnedSessionStore { session.pinnedStore! }
    private var server: LabServer!

    override func setUp() async throws {
        try await super.setUp()
        server = try await LabSharedServers.serverForSuite(LabRecipes.postgres)
        session = try await makeSession()
    }

    override func tearDown() async throws {
        await session?.close()
        try await super.tearDown()
    }

    private func makeSession() async throws -> PostgresSession {
        let base = try await PostgresNIOFactory().connect(
            host: server.host, port: server.port, database: "postgres", tls: false, tlsMode: .disable,
            authentication: DatabaseAuthenticationConfiguration(method: .sqlPassword, username: server.username, password: server.password)
        )
        return (base as! PostgresSession).withPinnedQueries()
    }

    private func run(_ sql: String, on session: PostgresSession? = nil) async throws -> QueryResultSet {
        try await (session ?? self.session).simpleQuery(sql, executionMode: nil, progressHandler: { _ in })
    }

    func testTheLimitStopsASlowStatement() async throws {
        _ = try await run("SELECT 1")
        await store.setStatementTimeout(.milliseconds(300))
        do {
            _ = try await run("SELECT pg_sleep(2)")
            XCTFail("the 300 ms limit should stop it")
        } catch {
            XCTAssertTrue(QueryTimeLimitStop.isStatementTimeout(error.localizedDescription), error.localizedDescription)
        }
        await store.setStatementTimeout(nil)
        _ = try await run("SELECT pg_sleep(0.5)")   // no Echo limit: the server's default (none here)
    }

    func testRunWithoutLimitLiftsEvenAServerLimit() async throws {
        _ = try await run("ALTER ROLE postgres SET statement_timeout = '300ms'")
        // The server is shared: the role's limit is gone before the next suite connects.
        let session = self.session!
        addTeardownBlock {
            _ = try? await session.simpleQuery("ALTER ROLE postgres RESET statement_timeout", executionMode: nil, progressHandler: { _ in })
        }
        let fresh = try await makeSession()
        defer { Task { await fresh.close() } }
        _ = try await run("SELECT 1", on: fresh)
        let serverLimit = await fresh.pinnedStore!.serverStatementTimeout(for: "postgres")
        XCTAssertEqual(serverLimit, 0.3, "the server's own limit is read (SL1)")

        await fresh.pinnedStore!.setStatementTimeout(.zero)
        _ = try await run("SELECT pg_sleep(0.6)", on: fresh)   // Run Without Limit
        await fresh.pinnedStore!.setStatementTimeout(nil)
        do {
            _ = try await run("SELECT pg_sleep(0.6)", on: fresh)
            XCTFail("back to the server's 300 ms")
        } catch {
            XCTAssertTrue(QueryTimeLimitStop.isStatementTimeout(error.localizedDescription))
        }
        _ = try await run("ALTER ROLE postgres RESET statement_timeout")
    }

    func testTheRunningBackendIsFoundForTheLockCheck() async throws {
        _ = try await run("SELECT 1")
        let idle = await store.runningBackendPID()
        XCTAssertNil(idle)
        let session = self.session!
        let running = Task { try await session.simpleQuery("SELECT pg_sleep(1)", executionMode: nil, progressHandler: { _ in }) }
        try await Task.sleep(for: .milliseconds(300))
        let pid = await store.runningBackendPID()
        XCTAssertNotNil(pid)
        _ = try await running.value
    }
}

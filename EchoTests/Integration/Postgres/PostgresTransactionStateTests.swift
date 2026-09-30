import XCTest
import PostgresKit
@testable import Echo

/// Round 21, transaction state (accepted): the tab follows BEGIN, a failed statement and ROLLBACK
/// from its own tracking (K1), which is what the footer's status pill shows.
///
/// Runs only when `ECHO_E2E_PG_PORT` points at a disposable server (user/password `postgres`).
@MainActor
final class PostgresTransactionStateTests: XCTestCase {
    private var session: PostgresSession!

    override func setUp() async throws {
        try await super.setUp()
        guard let portText = ProcessInfo.processInfo.environment["ECHO_E2E_PG_PORT"], let port = Int(portText) else {
            throw XCTSkip("ECHO_E2E_PG_PORT not set")
        }
        let base = try await PostgresNIOFactory().connect(
            host: "127.0.0.1", port: port, database: "postgres", tls: false, tlsMode: .disable,
            authentication: DatabaseAuthenticationConfiguration(method: .sqlPassword, username: "postgres", password: "postgres")
        )
        session = (base as! PostgresSession).withPinnedQueries()
    }

    override func tearDown() async throws {
        await session?.close()
        try await super.tearDown()
    }

    private func run(_ sql: String) async throws {
        _ = try await session.simpleQuery(sql, executionMode: nil, progressHandler: { _ in })
    }

    func testTheTabFollowsBeginAFailureAndRollback() async throws {
        try await run("SELECT 1")
        var status = await session.pinnedTransactionStatus()
        XCTAssertEqual(status, .idle)

        try await run("BEGIN")
        status = await session.pinnedTransactionStatus()
        XCTAssertEqual(status, .inTransaction)

        do { try await run("SELECT 1/0"); XCTFail("division by zero should fail") } catch {}
        status = await session.pinnedTransactionStatus()
        XCTAssertEqual(status, .failed)

        try await run("ROLLBACK")
        status = await session.pinnedTransactionStatus()
        XCTAssertEqual(status, .idle)
    }
}

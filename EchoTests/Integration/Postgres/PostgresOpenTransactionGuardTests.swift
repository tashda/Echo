import XCTest
import PostgresKit
@testable import Echo

/// Round 21, open transaction on close (accepted): the tab's store finds its open transactions
/// (checked with the server), commits or rolls them back, and a failed one is only rolled back.
///
/// Runs only when `ECHO_E2E_PG_PORT` points at a disposable server (user/password `postgres`).
@MainActor
final class PostgresOpenTransactionGuardTests: XCTestCase {
    private var session: PostgresSession!
    private var store: PostgresPinnedSessionStore { session.pinnedStore! }

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
        _ = try await run("DROP TABLE IF EXISTS guard_t")
        _ = try await run("CREATE TABLE guard_t (id int)")
    }

    override func tearDown() async throws {
        _ = try? await run("ROLLBACK")
        _ = try? await run("DROP TABLE IF EXISTS guard_t")
        await session?.close()
        try await super.tearDown()
    }

    @discardableResult
    private func run(_ sql: String) async throws -> QueryResultSet {
        try await session.simpleQuery(sql, executionMode: nil, progressHandler: { _ in })
    }

    private func count() async throws -> String? {
        try await session.client.simpleQueryResult("SELECT count(*)::text FROM guard_t").rows.first
            .flatMap { $0.first.flatMap(PostgresCellFormatter().stringValue(for:)) }
    }

    func testOpenTransactionsAreFoundWithTheirDetails() async throws {
        let none = await store.openTransactions()
        XCTAssertTrue(none.isEmpty)
        try await run("BEGIN")
        try await run("INSERT INTO guard_t VALUES (1)")
        try await run("INSERT INTO guard_t VALUES (2)")
        let open = await store.openTransactions()
        XCTAssertEqual(open.count, 1)
        XCTAssertEqual(open.first?.database, "postgres")
        XCTAssertEqual(open.first?.statements, 2)
        XCTAssertEqual(open.first?.failed, false)
        XCTAssertNotNil(open.first?.startedAt)
    }

    func testCommitKeepsTheWork() async throws {
        try await run("BEGIN")
        try await run("INSERT INTO guard_t VALUES (1)")
        try await store.endTransactions(commit: true)
        let rows = try await count()
        XCTAssertEqual(rows, "1")
        let open = await store.openTransactions()
        XCTAssertTrue(open.isEmpty)
    }

    func testRollBackDiscardsTheWork() async throws {
        try await run("BEGIN")
        try await run("INSERT INTO guard_t VALUES (1)")
        try await store.endTransactions(commit: false)
        let rows = try await count()
        XCTAssertEqual(rows, "0")
    }

    func testAFailedTransactionIsRolledBackEvenWhenCommitIsAsked() async throws {
        try await run("BEGIN")
        try await run("INSERT INTO guard_t VALUES (1)")
        do { try await run("SELECT 1/0") } catch {}
        let open = await store.openTransactions()
        XCTAssertEqual(open.first?.failed, true)
        try await store.endTransactions(commit: true)
        let rows = try await count()
        XCTAssertEqual(rows, "0")
        let after = await store.openTransactions()
        XCTAssertTrue(after.isEmpty)
    }

    func testACommitTheServerRefusesIsReported() async throws {
        try await run("CREATE TABLE IF NOT EXISTS guard_parent (id int PRIMARY KEY)")
        try await run("CREATE TABLE IF NOT EXISTS guard_child (parent int REFERENCES guard_parent DEFERRABLE INITIALLY DEFERRED)")
        defer { Task { [session = self.session!] in _ = try? await session.simpleQuery("DROP TABLE IF EXISTS guard_child, guard_parent", executionMode: nil, progressHandler: { _ in }) } }
        try await run("BEGIN")
        try await run("INSERT INTO guard_child VALUES (42)")   // checked at COMMIT
        do {
            try await store.endTransactions(commit: true)
            XCTFail("the deferred foreign key fails at COMMIT")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}

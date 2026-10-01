import XCTest
import PostgresKit
import ServerLabClient
@testable import Echo

/// End-to-end checks of a PostgreSQL query-tab session against a real server: pinned connection,
/// streaming past the 200-row preview, scripts and server-side cancel.
///
/// Runs on the lab Postgres the suites share (`LabSharedServers`).
@MainActor
final class PostgresQueryTabSessionTests: XCTestCase {
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

    func testRunsShareOneBackendAndKeepSessionState() async throws {
        let first = try await run("SELECT pg_backend_pid()")
        _ = try await run("SET search_path TO pg_catalog")
        _ = try await run("CREATE TEMP TABLE tab_state AS SELECT 42 AS answer")
        _ = try await run("BEGIN")
        _ = try await run("INSERT INTO tab_state VALUES (43)")
        let inside = try await run("SELECT count(*) FROM tab_state")
        _ = try await run("COMMIT")
        let second = try await run("SELECT pg_backend_pid()")
        let path = try await run("SHOW search_path")

        XCTAssertEqual(first.rows.first?.first, second.rows.first?.first, "every run uses the tab's backend")
        XCTAssertEqual(inside.rows.first?.first, "2")
        XCTAssertEqual(path.rows.first?.first, "pg_catalog")
    }

    func testStreamsEveryRowAndFormatsTypes() async throws {
        let result = try await run("SELECT g, ARRAY[g, g + 1], interval '1 day' * g FROM generate_series(1, 1000) g")
        XCTAssertEqual(result.totalRowCount, 1000)
        XCTAssertEqual(result.rows.first, ["1", "{1,2}", "1 day"])
    }

    func testScriptsRunStatementByStatement() async throws {
        let results = try await session.executeBatches(
            ["CREATE TEMP TABLE script_t (id int, note text)", "INSERT INTO script_t VALUES (1, 'a;b'), (2, 'c')", "SELECT * FROM script_t ORDER BY id", "SELECT * FROM missing_table_xyz", "SELECT 1"],
            progressHandler: nil
        )
        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(results[1].messages.first?.message, "INSERT 0 2")
        XCTAssertEqual(results[2].resultSets.first?.rows, [["1", "a;b"], ["2", "c"]])
        XCTAssertNotNil(results[3].error)
        XCTAssertTrue(results[3].error?.contains("missing_table_xyz") == true)
        XCTAssertTrue(results[4].skipped, "a script stops at the failed statement by default (round 21, E3)")
    }

    func testCancelStopsTheStatementOnTheServer() async throws {
        let session = self.session!
        let started = Date()
        let running = Task { try await session.simpleQuery("SELECT pg_sleep(10)", executionMode: nil, progressHandler: { _ in }) }
        try await Task.sleep(for: .milliseconds(700))
        let sent = await session.cancelRunningQuery()
        XCTAssertTrue(sent)
        do {
            _ = try await running.value
            XCTFail("the statement should be cancelled")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("57014"), error.localizedDescription)
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 4)
        let after = try await run("SELECT 1")
        XCTAssertEqual(after.rows.first?.first, "1")
    }

    func testRelaclIsReadableWithoutCasting() async throws {
        let result = try await run("SELECT relname, relacl FROM pg_class WHERE relacl IS NOT NULL LIMIT 1")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertTrue(result.rows.first?[1]?.hasPrefix("{") == true)
    }
}

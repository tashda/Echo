import XCTest
import PostgresKit
import ServerLabClient
@testable import Echo

/// Round 21, script results (accepted): E3 stop at a failed statement (a setting continues) and
/// OT1 Run as One Transaction, against a real server.
///
/// Runs on the lab Postgres the suites share (`LabSharedServers`).
@MainActor
final class PostgresScriptRunTests: XCTestCase {
    private var session: PostgresSession!

    override func setUp() async throws {
        try await super.setUp()
        let server = try await labServer(LabRecipes.postgres)
        let base = try await PostgresNIOFactory().connect(
            host: server.host, port: server.port, database: "postgres", tls: false, tlsMode: .disable,
            authentication: DatabaseAuthenticationConfiguration(method: .sqlPassword, username: server.username, password: server.password)
        )
        session = (base as! PostgresSession).withPinnedQueries()
        _ = try await session.simpleQuery("DROP TABLE IF EXISTS script_run_t", executionMode: nil, progressHandler: { _ in })
        _ = try await session.simpleQuery("CREATE TABLE script_run_t (id int PRIMARY KEY)", executionMode: nil, progressHandler: { _ in })
    }

    override func tearDown() async throws {
        _ = try? await session?.simpleQuery("DROP TABLE IF EXISTS script_run_t", executionMode: nil, progressHandler: { _ in })
        await session?.close()
        try await super.tearDown()
    }

    private func count() async throws -> String? {
        try await session.simpleQuery("SELECT count(*) FROM script_run_t", executionMode: nil, progressHandler: { _ in }).rows.first?.first ?? nil
    }

    private let script = [
        "INSERT INTO script_run_t VALUES (1)",
        "INSERT INTO script_run_t VALUES (1)",   // fails: duplicate key
        "INSERT INTO script_run_t VALUES (2)",
        "SELECT id FROM script_run_t ORDER BY id",
    ]

    func testStopsAtTheFailedStatementByDefault() async throws {
        let run = try await session.executeScript(script, options: PostgresScriptOptions(), progressHandler: nil)
        XCTAssertEqual(run.results.map(\.skipped), [false, false, true, true])
        XCTAssertNotNil(run.results[1].error)
        XCTAssertEqual(run.transaction, .notRequested)
        XCTAssertNotNil(run.results[0].duration)
        let rows = try await count()
        XCTAssertEqual(rows, "1", "statement 1 committed on its own")
        let lines = PostgresScriptSummary.lines(results: run.results, transaction: run.transaction)
        XCTAssertEqual(lines.first?.text, "Stopped: statement 2 failed; statements 3 and 4 were not run.")
    }

    func testTheSettingContinuesAfterAFailedStatement() async throws {
        let run = try await session.executeScript(script, options: PostgresScriptOptions(stopOnError: false), progressHandler: nil)
        XCTAssertEqual(run.results.map(\.skipped), [false, false, false, false])
        XCTAssertEqual(run.results[3].resultSets.first?.rows, [["1"], ["2"]])
    }

    func testOneTransactionRollsBackEverythingWhenAStatementFails() async throws {
        let run = try await session.executeScript(script, options: PostgresScriptOptions(asOneTransaction: true), progressHandler: nil)
        XCTAssertEqual(run.transaction, .rolledBack(failedStatement: 1))
        let rows = try await count()
        XCTAssertEqual(rows, "0", "nothing was saved")
        let state = try await session.simpleQuery("SELECT 1", executionMode: nil, progressHandler: { _ in })
        XCTAssertEqual(state.rows.first?.first, "1", "the tab is usable afterwards (no aborted transaction left)")
    }

    func testOneTransactionCommitsWhenEveryStatementSucceeds() async throws {
        let run = try await session.executeScript(
            ["INSERT INTO script_run_t VALUES (1)", "INSERT INTO script_run_t VALUES (2)"],
            options: PostgresScriptOptions(asOneTransaction: true), progressHandler: nil
        )
        XCTAssertEqual(run.transaction, .committed)
        let rows = try await count()
        XCTAssertEqual(rows, "2")
    }

    func testAScriptWithItsOwnTransactionRunsAsWritten() async throws {
        let run = try await session.executeScript(
            ["BEGIN", "INSERT INTO script_run_t VALUES (5)", "COMMIT"],
            options: PostgresScriptOptions(asOneTransaction: true), progressHandler: nil
        )
        XCTAssertEqual(run.transaction, .scriptManagesItsOwn)
        let rows = try await count()
        XCTAssertEqual(rows, "1")
    }
}

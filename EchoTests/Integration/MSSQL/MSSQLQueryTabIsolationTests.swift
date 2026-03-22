import XCTest
import SQLServerKit
@testable import Echo

/// Tests query tab isolation using dedicated sessions.
///
/// Uses `MSSQLDedicatedDockerTestCase` to verify that separate query tabs
/// (each with their own dedicated `SQLServerConnection`) maintain independent
/// database context, temp tables, and query execution state.
final class MSSQLQueryTabIsolationTests: MSSQLDedicatedDockerTestCase {

    func testDedicatedQueryTabsKeepDatabaseContextIsolated() async throws {
        let tabOne = dedicatedSession!
        let tabTwo = try await makeDedicatedSession()
        addTeardownBlock { await tabTwo.close() }

        _ = try await tabOne.sessionForDatabase("tempdb")

        let tabOneDatabase = try await tabOne.currentDatabaseName()
        let tabTwoDatabase = try await tabTwo.currentDatabaseName()

        XCTAssertEqual(tabOneDatabase?.lowercased(), "tempdb")
        XCTAssertEqual(tabTwoDatabase?.lowercased(), "master")
    }

    func testDedicatedQueryTabsDoNotShareTemporaryTables() async throws {
        let tabOne = dedicatedSession!
        let tabTwo = try await makeDedicatedSession()
        addTeardownBlock { await tabTwo.close() }

        _ = try await tabOne.executeUpdate("CREATE TABLE #echo_tab_isolation (id INT)")

        let tabOneVisibility = try await tabOne.simpleQuery(
            "SELECT CASE WHEN OBJECT_ID('tempdb..#echo_tab_isolation') IS NULL THEN 0 ELSE 1 END AS visible"
        )
        let tabTwoVisibility = try await tabTwo.simpleQuery(
            "SELECT CASE WHEN OBJECT_ID('tempdb..#echo_tab_isolation') IS NULL THEN 0 ELSE 1 END AS visible"
        )

        XCTAssertEqual(tabOneVisibility.rows.first?.first, "1")
        XCTAssertEqual(tabTwoVisibility.rows.first?.first, "0")
    }

    func testCancellingOneDedicatedQueryTabDoesNotPoisonOtherTabsOrItself() async throws {
        let tabOne = dedicatedSession!
        let tabTwo = try await makeDedicatedSession()
        addTeardownBlock { await tabTwo.close() }

        let longRunningQuery = Task {
            try await tabOne.simpleQuery("WAITFOR DELAY '00:00:10'; SELECT 1 AS delayed")
        }

        try await Task.sleep(for: .milliseconds(1000))
        longRunningQuery.cancel()

        do {
            _ = try await longRunningQuery.value
            // Query completed before cancellation reached it — acceptable
        } catch {
            // Cancellation or driver-level error — expected
        }

        // The key assertion: other tabs must still work
        let unaffectedTabResult = try await tabTwo.simpleQuery("SELECT 2 AS value")
        XCTAssertEqual(unaffectedTabResult.rows.first?.first, "2")

        // And the cancelled tab must recover for subsequent queries
        let recoveredTabResult = try await tabOne.simpleQuery("SELECT 1 AS value")
        XCTAssertEqual(recoveredTabResult.rows.first?.first, "1")
    }

    func testCancellingStreamedDedicatedQueryDoesNotPoisonTab() async throws {
        let tab = dedicatedSession!

        let longRunningQuery = Task {
            try await tab.simpleQuery(
                """
                WAITFOR DELAY '00:00:05';
                SELECT TOP 5000
                    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_id
                FROM sys.all_objects AS a
                CROSS JOIN sys.all_objects AS b
                """,
                progressHandler: { _ in }
            )
        }

        try await Task.sleep(for: .milliseconds(1000))
        longRunningQuery.cancel()

        do {
            _ = try await longRunningQuery.value
            // Query completed before cancellation reached it — acceptable
        } catch {
            // Cancellation or driver-level error — expected
        }

        // The key assertion: tab must recover for subsequent queries
        let recoveredTabResult = try await tab.simpleQuery("SELECT 1 AS value")
        XCTAssertEqual(recoveredTabResult.rows.first?.first, "1")
    }
}

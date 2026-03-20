import XCTest
import SQLServerKit
@testable import Echo

final class MSSQLQueryTabIsolationTests: MSSQLDockerTestCase {
    private var metadataSession: SQLServerSessionAdapter {
        session as! SQLServerSessionAdapter
    }

    private func makeDedicatedQuerySession(
        database: String? = nil
    ) async throws -> MSSQLDedicatedQuerySession {
        let configuration = try MSSQLNIOFactory.makeConnectionConfiguration(
            host: "127.0.0.1",
            port: Self.port,
            database: database,
            tls: false,
            trustServerCertificate: true,
            sslRootCertPath: nil,
            mssqlEncryptionMode: .optional,
            readOnlyIntent: false,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: Self.username,
                password: Self.password
            ),
            connectTimeoutSeconds: 15
        )
        let connection = try await SQLServerConnection.connect(
            configuration: configuration
        )

        let querySession = MSSQLDedicatedQuerySession(
            connection: connection,
            configuration: configuration,
            metadataSession: metadataSession
        )

        addTeardownBlock {
            await querySession.close()
        }

        return querySession
    }

    func testDedicatedQueryTabsKeepDatabaseContextIsolated() async throws {
        let tabOne = try await makeDedicatedQuerySession()
        let tabTwo = try await makeDedicatedQuerySession()

        _ = try await tabOne.sessionForDatabase("tempdb")

        let tabOneDatabase = try await tabOne.currentDatabaseName()
        let tabTwoDatabase = try await tabTwo.currentDatabaseName()

        XCTAssertEqual(tabOneDatabase?.lowercased(), "tempdb")
        XCTAssertEqual(tabTwoDatabase?.lowercased(), "master")
    }

    func testDedicatedQueryTabsDoNotShareTemporaryTables() async throws {
        let tabOne = try await makeDedicatedQuerySession()
        let tabTwo = try await makeDedicatedQuerySession()

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
        let tabOne = try await makeDedicatedQuerySession()
        let tabTwo = try await makeDedicatedQuerySession()

        let longRunningQuery = Task {
            try await tabOne.simpleQuery("WAITFOR DELAY '00:00:10'; SELECT 1 AS delayed")
        }

        try await Task.sleep(for: .milliseconds(300))
        longRunningQuery.cancel()

        do {
            _ = try await longRunningQuery.value
            XCTFail("Expected the long-running query to be cancelled")
        } catch is CancellationError {
            // Expected
        } catch {
            // Driver-level cancellation can surface as a transport/query error.
        }

        let unaffectedTabResult = try await tabTwo.simpleQuery("SELECT 2 AS value")
        XCTAssertEqual(unaffectedTabResult.rows.first?.first, "2")

        let recoveredTabResult = try await tabOne.simpleQuery("SELECT 1 AS value")
        XCTAssertEqual(recoveredTabResult.rows.first?.first, "1")
    }

    func testCancellingStreamedDedicatedQueryDoesNotPoisonTab() async throws {
        let tab = try await makeDedicatedQuerySession()

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

        try await Task.sleep(for: .milliseconds(250))
        longRunningQuery.cancel()

        do {
            _ = try await longRunningQuery.value
            XCTFail("Expected streamed query to be cancelled")
        } catch is CancellationError {
            // Expected.
        } catch {
            // Driver-level cancellation may surface as a query/transport error.
        }

        let recoveredTabResult = try await tab.simpleQuery("SELECT 1 AS value")
        XCTAssertEqual(recoveredTabResult.rows.first?.first, "1")
    }
}

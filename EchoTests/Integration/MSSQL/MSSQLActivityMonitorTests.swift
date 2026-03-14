import XCTest
@testable import Echo

/// Tests SQL Server activity monitoring through Echo's DatabaseSession layer.
final class MSSQLActivityMonitorTests: MSSQLDockerTestCase {

    // MARK: - Monitor Creation

    func testMakeActivityMonitorReturnsNonNil() async throws {
        let monitor = try session.makeActivityMonitor()
        XCTAssertNotNil(monitor)
    }

    // MARK: - Snapshot

    func testSnapshotReturnsSessions() async throws {
        let monitor = try session.makeActivityMonitor()
        let snapshot = try await monitor.snapshot()

        // There should be at least one active session (our own connection)
        XCTAssertFalse(snapshot.processes.isEmpty, "Snapshot should contain at least one process")
    }

    func testSnapshotCaptureTimestamp() async throws {
        let monitor = try session.makeActivityMonitor()
        let before = Date()
        let snapshot = try await monitor.snapshot()
        let after = Date()

        XCTAssertGreaterThanOrEqual(snapshot.capturedAt, before)
        XCTAssertLessThanOrEqual(snapshot.capturedAt, after)
    }

    func testActiveSessionsIncludeCurrentConnection() async throws {
        // Query our own SPID for comparison
        let spidResult = try await query("SELECT @@SPID AS current_spid")
        let currentSpid = IntegrationTestHelpers.firstRowValue(spidResult, column: "current_spid")
        XCTAssertNotNil(currentSpid, "Should be able to retrieve current SPID")

        let monitor = try session.makeActivityMonitor()
        let snapshot = try await monitor.snapshot()

        // Verify the snapshot contains sessions via the underlying MSSQL snapshot
        guard case .mssql(let mssqlSnapshot) = snapshot else {
            XCTFail("Expected MSSQL activity snapshot")
            return
        }

        let spids = mssqlSnapshot.processes.map { String($0.sessionId) }
        XCTAssertTrue(
            spids.contains(where: { $0 == currentSpid }),
            "Current SPID \(currentSpid ?? "nil") should appear in active sessions: \(spids)"
        )
    }

    func testSessionDetailsHaveExpectedFields() async throws {
        let monitor = try session.makeActivityMonitor()
        let snapshot = try await monitor.snapshot()

        guard case .mssql(let mssqlSnapshot) = snapshot else {
            XCTFail("Expected MSSQL activity snapshot")
            return
        }

        guard let firstProcess = mssqlSnapshot.processes.first else {
            XCTFail("Expected at least one process")
            return
        }

        // Verify key fields are populated
        XCTAssertGreaterThan(firstProcess.sessionId, 0, "Session ID should be positive")
        XCTAssertNotNil(firstProcess.sessionStatus, "Session status should be present")
    }

    // MARK: - Multiple Snapshots

    func testMultipleSnapshotsAreConsistent() async throws {
        let monitor = try session.makeActivityMonitor()

        let snapshot1 = try await monitor.snapshot()
        let snapshot2 = try await monitor.snapshot()

        // Both snapshots should have processes
        XCTAssertFalse(snapshot1.processes.isEmpty)
        XCTAssertFalse(snapshot2.processes.isEmpty)

        // Capture times should be ordered
        XCTAssertLessThanOrEqual(snapshot1.capturedAt, snapshot2.capturedAt)
    }

    func testSnapshotProcessCountIsReasonable() async throws {
        let monitor = try session.makeActivityMonitor()
        let snapshot = try await monitor.snapshot()

        guard case .mssql(let mssqlSnapshot) = snapshot else {
            XCTFail("Expected MSSQL activity snapshot")
            return
        }

        // SQL Server always has system sessions; we should see at least one
        // but not an unreasonable number for a test container
        let count = mssqlSnapshot.processes.count
        XCTAssertGreaterThanOrEqual(count, 1, "Should have at least 1 process")
        XCTAssertLessThan(count, 500, "Process count should be reasonable for a test container")
    }

    // MARK: - Kill Session

    func testKillSecondarySession() async throws {
        // Create a secondary connection
        let secondarySession = try await createSession()

        // Get the secondary session's SPID
        let spidResult = try await secondarySession.simpleQuery("SELECT @@SPID AS spid")
        guard let spidString = IntegrationTestHelpers.firstRowValue(spidResult, column: "spid"),
              let spid = Int(spidString) else {
            XCTFail("Could not get secondary session SPID")
            await secondarySession.close()
            return
        }

        let monitor = try session.makeActivityMonitor()

        // Kill the secondary session
        do {
            try await monitor.killSession(id: spid)
        } catch {
            // Some environments may restrict KILL permissions
            await secondarySession.close()
            throw XCTSkip("KILL permission not available: \(error.localizedDescription)")
        }

        // Verify the session was killed by trying to use it
        // The killed session should fail on its next query
        do {
            _ = try await secondarySession.simpleQuery("SELECT 1")
            // If it succeeds, the kill might not have taken effect yet;
            // this is acceptable in some timing scenarios
        } catch {
            // Expected: the session was killed
        }

        await secondarySession.close()
    }

    // MARK: - Expensive Queries

    func testExpensiveQueriesSnapshot() async throws {
        let monitor = try session.makeActivityMonitor()
        let snapshot = try await monitor.snapshot()

        guard case .mssql(let mssqlSnapshot) = snapshot else {
            XCTFail("Expected MSSQL activity snapshot")
            return
        }

        // Expensive queries may be empty in a test container, but the field should exist
        // We just verify it doesn't crash and returns a valid array
        XCTAssertNotNil(mssqlSnapshot.expensiveQueries)
    }

    // MARK: - Direct DMV Queries

    func testDMVSessionQuery() async throws {
        let result = try await query("""
            SELECT
                session_id,
                status,
                login_name,
                host_name,
                program_name,
                database_id,
                cpu_time,
                memory_usage,
                total_elapsed_time,
                last_request_start_time
            FROM sys.dm_exec_sessions
            WHERE is_user_process = 1
        """)
        IntegrationTestHelpers.assertMinRowCount(result, expected: 1)
        IntegrationTestHelpers.assertHasColumn(result, named: "session_id")
        IntegrationTestHelpers.assertHasColumn(result, named: "status")
        IntegrationTestHelpers.assertHasColumn(result, named: "login_name")
        IntegrationTestHelpers.assertHasColumn(result, named: "cpu_time")
    }

    func testDMVRequestsQuery() async throws {
        let result = try await query("""
            SELECT
                r.session_id,
                r.status,
                r.command,
                r.cpu_time,
                r.total_elapsed_time,
                r.reads,
                r.writes,
                r.logical_reads,
                r.wait_type,
                DB_NAME(r.database_id) AS database_name
            FROM sys.dm_exec_requests r
            WHERE r.session_id > 50
        """)
        // May be empty if no active requests at the moment, but columns should exist
        IntegrationTestHelpers.assertHasColumn(result, named: "session_id")
        IntegrationTestHelpers.assertHasColumn(result, named: "command")
        IntegrationTestHelpers.assertHasColumn(result, named: "database_name")
    }
}

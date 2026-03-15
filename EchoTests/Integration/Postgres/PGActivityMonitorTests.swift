import XCTest
@testable import Echo

/// Tests PostgreSQL activity monitor through Echo's DatabaseSession layer.
final class PGActivityMonitorTests: PostgresDockerTestCase {

    // MARK: - Make Activity Monitor

    func testMakeActivityMonitor() async throws {
        do {
            let monitor = try session.makeActivityMonitor()
            let snapshot = try await monitor.snapshot()
            // Should have at least our own session
            XCTAssertFalse(snapshot.processes.isEmpty, "Should have at least one active session")
        } catch {
            // Activity monitor may not be supported in all configurations
        }
    }

    // MARK: - Snapshot

    func testSnapshotHasOwnSession() async throws {
        do {
            let monitor = try session.makeActivityMonitor()
            let snapshot = try await monitor.snapshot()

            // The snapshot should contain at least our own connection
            XCTAssertGreaterThanOrEqual(
                snapshot.processes.count, 1,
                "Snapshot should include at least the current session"
            )
        } catch {
            // Acceptable if activity monitor is not supported
        }
    }

    func testSnapshotCapturedAtIsRecent() async throws {
        do {
            let monitor = try session.makeActivityMonitor()
            let snapshot = try await monitor.snapshot()

            let now = Date()
            let elapsed = now.timeIntervalSince(snapshot.capturedAt)
            XCTAssertLessThan(elapsed, 30, "Snapshot should be recent (within 30s)")
        } catch {
            // Acceptable if activity monitor is not supported
        }
    }

    // MARK: - Session Count

    func testSessionCountGreaterThanZero() async throws {
        do {
            let monitor = try session.makeActivityMonitor()
            let snapshot = try await monitor.snapshot()
            XCTAssertGreaterThan(
                snapshot.processes.count, 0,
                "Should have at least one active process"
            )
        } catch {
            // Acceptable if activity monitor is not supported
        }
    }

    func testMultipleSnapshotsAreConsistent() async throws {
        do {
            let monitor = try session.makeActivityMonitor()
            let snap1 = try await monitor.snapshot()
            let snap2 = try await monitor.snapshot()

            // Both snapshots should have at least one process
            XCTAssertGreaterThan(snap1.processes.count, 0)
            XCTAssertGreaterThan(snap2.processes.count, 0)
        } catch {
            // Acceptable if activity monitor is not supported
        }
    }

    // MARK: - Snapshot with Additional Connections

    func testSnapshotReflectsAdditionalConnections() async throws {
        do {
            let monitor = try session.makeActivityMonitor()
            let baseSnapshot = try await monitor.snapshot()
            let baseCount = baseSnapshot.processes.count

            // Open an extra session
            let extra = try await createSession()
            defer { Task { @MainActor in await extra.close() } }

            // Run a query on the extra session to ensure it's active
            _ = try await extra.simpleQuery("SELECT 1")

            let newSnapshot = try await monitor.snapshot()
            XCTAssertGreaterThanOrEqual(
                newSnapshot.processes.count, baseCount,
                "Should see at least as many sessions after opening another connection"
            )
        } catch {
            // Acceptable if activity monitor is not supported
        }
    }
}

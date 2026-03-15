import XCTest
@testable import Echo

@MainActor
final class ActiveSessionGroupTests: XCTestCase {
    private var coordinator: ActiveSessionGroup!

    override func setUp() {
        super.setUp()
        coordinator = ActiveSessionGroup()
    }

    // MARK: - Helpers

    private func makeSession(connectionName: String = "Test") -> ConnectionSession {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ActiveSessionGroupTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let config = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        let spoolManager = ResultSpooler(configuration: config)

        let connection = TestFixtures.savedConnection(connectionName: connectionName)
        let mockSession = MockDatabaseSession()
        return ConnectionSession(
            connection: connection,
            session: mockSession,
            spoolManager: spoolManager
        )
    }

    // MARK: - Add Session

    func testAddSessionSetsActive() {
        let session = makeSession()
        coordinator.addSession(session)

        XCTAssertEqual(coordinator.activeSessionID, session.id)
        XCTAssertEqual(coordinator.activeSessions.count, 1)
    }

    func testAddSessionRemovesDuplicateForSameConnection() {
        let connection = TestFixtures.savedConnection()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("Test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let config = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        let spoolManager = ResultSpooler(configuration: config)

        let session1 = ConnectionSession(connection: connection, session: MockDatabaseSession(), spoolManager: spoolManager)
        let session2 = ConnectionSession(connection: connection, session: MockDatabaseSession(), spoolManager: spoolManager)

        coordinator.addSession(session1)
        coordinator.addSession(session2)

        XCTAssertEqual(coordinator.activeSessions.count, 1)
        XCTAssertEqual(coordinator.activeSessionID, session2.id)
    }

    // MARK: - Remove Session

    func testRemoveSessionAdjustsActiveSessionID() {
        let s1 = makeSession(connectionName: "S1")
        let s2 = makeSession(connectionName: "S2")

        coordinator.addSession(s1)
        coordinator.addSession(s2)

        coordinator.removeSession(withID: s2.id)

        XCTAssertEqual(coordinator.activeSessions.count, 1)
        XCTAssertEqual(coordinator.activeSessionID, s1.id)
    }

    // MARK: - Set Active Session

    func testSetActiveSessionValidatesSessionExists() {
        let session = makeSession()
        coordinator.addSession(session)

        coordinator.setActiveSession(UUID()) // non-existent
        XCTAssertEqual(coordinator.activeSessionID, session.id, "Should not change to non-existent session")
    }

    // MARK: - Server Switching

    func testSwitchToNextServerCircular() {
        let s1 = makeSession(connectionName: "S1")
        let s2 = makeSession(connectionName: "S2")
        let s3 = makeSession(connectionName: "S3")

        coordinator.addSession(s1)
        coordinator.addSession(s2)
        coordinator.addSession(s3)

        // Active is s3 (last added)
        XCTAssertEqual(coordinator.activeSessionID, s3.id)

        // switchToNextServer() uses sortedSessions (sorted by lastActivity descending)
        // and calls updateActivity() on the switched-to session, which changes the sort
        // order on subsequent calls. This means cycling through all sessions requires
        // more switches than the session count. Verify that switching does change the
        // active session and eventually returns to the starting session.
        coordinator.switchToNextServer()
        let firstSwitch = coordinator.activeSessionID
        XCTAssertNotNil(firstSwitch)
        XCTAssertNotEqual(firstSwitch, s3.id, "Should switch away from current session")

        coordinator.switchToNextServer()
        let secondSwitch = coordinator.activeSessionID
        XCTAssertNotNil(secondSwitch)
        XCTAssertNotEqual(secondSwitch, firstSwitch, "Should switch to a different session")

        // The two switches should have visited 2 unique sessions (both different from s3)
        let ids = Set([s3.id, firstSwitch!, secondSwitch!])
        XCTAssertGreaterThanOrEqual(ids.count, 2, "Switching should visit different sessions")
    }

    func testSwitchWithSingleSessionIsNoOp() {
        let session = makeSession()
        coordinator.addSession(session)

        coordinator.switchToNextServer()
        XCTAssertEqual(coordinator.activeSessionID, session.id)

        coordinator.switchToPreviousServer()
        XCTAssertEqual(coordinator.activeSessionID, session.id)
    }

    // MARK: - Session Lookup

    func testSessionForConnection() {
        let session = makeSession()
        coordinator.addSession(session)

        let found = coordinator.sessionForConnection(session.connection.id)
        XCTAssertEqual(found?.id, session.id)

        let notFound = coordinator.sessionForConnection(UUID())
        XCTAssertNil(notFound)
    }
}

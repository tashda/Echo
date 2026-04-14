import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("Project Switching")
struct ProjectSwitchTests {

    // MARK: - closeAllTabs

    @Test func closeAllTabsRemovesEveryTab() {
        let director = TabDirector()
        let delegate = MockTabDirectorDelegate()
        director.delegate = delegate

        director.addTab(makeTab(title: "One"))
        director.addTab(makeTab(title: "Two"))
        director.addTab(makeTab(title: "Three"))

        director.closeAllTabs()

        #expect(director.tabs.isEmpty)
        #expect(director.activeTabId == nil)
        #expect(delegate.removedTabIDs.count == 3)
    }

    @Test func closeAllTabsOnEmptyDirectorIsNoOp() {
        let director = TabDirector()
        director.closeAllTabs()
        #expect(director.tabs.isEmpty)
    }

    @Test func tabStoreCloseAllTabsSyncs() {
        let store = TabStore()
        store.addTab(makeTab(title: "A"))
        store.addTab(makeTab(title: "B"))

        store.closeAllTabs()

        #expect(store.tabs.isEmpty)
        #expect(store.hasTabs == false)
    }

    // MARK: - ActiveSessionGroup disconnectAll

    @Test func disconnectAllSessionsClearsAllSessions() {
        let group = ActiveSessionGroup()
        let conn1 = TestFixtures.savedConnection(id: UUID(), connectionName: "S1")
        let conn2 = TestFixtures.savedConnection(id: UUID(), connectionName: "S2")
        let session1 = ConnectionSession(connection: conn1, session: MockDatabaseSession(), spoolManager: makeSpooler())
        let session2 = ConnectionSession(connection: conn2, session: MockDatabaseSession(), spoolManager: makeSpooler())

        group.addSession(session1)
        group.addSession(session2)
        #expect(group.activeSessions.count == 2)

        let sessionIDs = group.activeSessions.map(\.id)
        for id in sessionIDs {
            group.removeSession(withID: id)
        }

        #expect(group.activeSessions.isEmpty)
        #expect(group.activeSessionID == nil)
    }

    // MARK: - RecentConnectionRecord projectID

    @Test func recentConnectionRecordEncodesDecode() throws {
        let projectID = UUID()
        let record = RecentConnectionRecord(
            id: UUID(),
            connectionName: "Test",
            host: "localhost",
            databaseName: "testdb",
            username: "user",
            databaseType: .postgresql,
            colorHex: "007AFF",
            lastUsedAt: Date(),
            projectID: projectID
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(RecentConnectionRecord.self, from: data)

        #expect(decoded.projectID == projectID)
        #expect(decoded.connectionName == "Test")
    }

    @Test func recentConnectionRecordBackwardsCompatibleWithoutProjectID() throws {
        // Simulate old data without projectID field
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "connectionName": "Legacy",
            "host": "localhost",
            "databaseName": "db",
            "username": "user",
            "databaseType": "postgresql",
            "colorHex": "007AFF",
            "lastUsedAt": 0
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RecentConnectionRecord.self, from: data)
        #expect(decoded.projectID == nil)
    }

    @Test func mockHistoryRepositoryFiltersbyProject() {
        let repo = MockHistoryRepository()
        let projectA = UUID()
        let projectB = UUID()

        repo.records = [
            RecentConnectionRecord(id: UUID(), connectionName: "A1", host: "a", databaseName: nil, username: nil, databaseType: .postgresql, colorHex: nil, lastUsedAt: Date(), projectID: projectA),
            RecentConnectionRecord(id: UUID(), connectionName: "B1", host: "b", databaseName: nil, username: nil, databaseType: .postgresql, colorHex: nil, lastUsedAt: Date(), projectID: projectB),
            RecentConnectionRecord(id: UUID(), connectionName: "A2", host: "a", databaseName: nil, username: nil, databaseType: .postgresql, colorHex: nil, lastUsedAt: Date(), projectID: projectA),
        ]

        let filtered = repo.loadRecentConnections(forProjectID: projectA)
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.projectID == projectA })
    }

    // MARK: - Helpers

    private func makeTab(title: String = "Tab") -> WorkspaceTab {
        let connection = TestFixtures.savedConnection()
        let session = MockDatabaseSession()
        let spooler = makeSpooler()
        let queryState = QueryEditorState(sql: "SELECT 1;", spoolManager: spooler)
        return WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: UUID(),
            title: title,
            content: .query(queryState)
        )
    }

    private func makeSpooler() -> ResultSpooler {
        let config = ResultSpoolConfiguration.defaultConfiguration(
            rootDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        return ResultSpooler(configuration: config)
    }
}

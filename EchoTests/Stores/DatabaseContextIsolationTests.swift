import Foundation
import Testing
@testable import Echo

@MainActor
struct DatabaseContextIsolationTests {
    private func makeSpoolManager() -> ResultSpooler {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("DatabaseContextIsolation-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let configuration = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        return ResultSpooler(configuration: configuration)
    }

    private func makeSession(
        database: String = "master",
        sidebarFocused: String? = nil
    ) -> ConnectionSession {
        let session = ConnectionSession(
            connection: TestFixtures.savedConnection(connectionName: "Test Server", database: database),
            session: MockDatabaseSession(),
            spoolManager: makeSpoolManager()
        )
        session.sidebarFocusedDatabase = sidebarFocused
        return session
    }

    // MARK: - Tab/Sidebar Independence

    @Test func tabDatabaseDoesNotChangeSidebarFocus() {
        let session = makeSession(database: "master", sidebarFocused: "master")
        let tab = session.addQueryTab(withQuery: "", database: "analytics")
        session.activeQueryTabID = tab.id

        // Tab switched to analytics, but sidebar should still be focused on master
        #expect(session.sidebarFocusedDatabase == "master")
        #expect(tab.activeDatabaseName == "analytics")
    }

    @Test func sidebarFocusDoesNotChangeTabDatabase() {
        let session = makeSession(database: "master", sidebarFocused: "master")
        let tab = session.addQueryTab(withQuery: "", database: "analytics")
        session.activeQueryTabID = tab.id

        // User expands a different database in sidebar
        session.sidebarFocusedDatabase = "reporting"

        // Tab should still be on analytics
        #expect(tab.activeDatabaseName == "analytics")
        #expect(session.activeDatabaseName == "analytics")
    }

    @Test func twoTabsOnDifferentDatabasesMaintainContext() {
        let session = makeSession(database: "master")
        let tabA = session.addQueryTab(withQuery: "SELECT * FROM users", database: "dbA")
        let tabB = session.addQueryTab(withQuery: "SELECT * FROM orders", database: "dbB")

        session.activeQueryTabID = tabA.id
        #expect(session.activeDatabaseName == "dbA")

        session.activeQueryTabID = tabB.id
        #expect(session.activeDatabaseName == "dbB")

        // Verify tab A still has its own database
        #expect(tabA.activeDatabaseName == "dbA")
        #expect(tabB.activeDatabaseName == "dbB")
    }

    // MARK: - activeDatabaseName Cascade

    @Test func activeDatabasePrefersTabOverSidebarOverConnection() {
        let session = makeSession(database: "defaultdb", sidebarFocused: "sidebar_db")
        let tab = session.addQueryTab(withQuery: "", database: "tab_db")
        session.activeQueryTabID = tab.id

        #expect(session.activeDatabaseName == "tab_db")
    }

    @Test func activeDatabaseFallsBackToSidebarWhenNoActiveTab() {
        let session = makeSession(database: "defaultdb", sidebarFocused: "sidebar_db")

        #expect(session.activeDatabaseName == "sidebar_db")
    }

    @Test func activeDatabaseFallsBackToConnectionWhenNoSidebarFocus() {
        let session = makeSession(database: "defaultdb")

        #expect(session.activeDatabaseName == "defaultdb")
    }

    @Test func activeDatabaseIsNilWhenAllSourcesEmpty() {
        let session = makeSession(database: "")

        #expect(session.activeDatabaseName == nil)
    }

    // MARK: - DatabaseContextID

    @Test func databaseContextIDEquality() {
        let id1 = UUID()
        let a = DatabaseContextID(connectionSessionID: id1, databaseName: "mydb")
        let b = DatabaseContextID(connectionSessionID: id1, databaseName: "mydb")
        let c = DatabaseContextID(connectionSessionID: UUID(), databaseName: "mydb")

        #expect(a == b)
        #expect(a != c)
    }

    @Test func databaseContextIDHashable() {
        let id1 = UUID()
        let a = DatabaseContextID(connectionSessionID: id1, databaseName: "mydb")
        let b = DatabaseContextID(connectionSessionID: id1, databaseName: "mydb")

        var set: Set<DatabaseContextID> = [a]
        set.insert(b)
        #expect(set.count == 1)
    }
}

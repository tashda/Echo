import Foundation
import Testing
@testable import Echo

@MainActor
struct QueryTabDatabaseContextTests {
    private func makeSpoolManager() -> ResultSpooler {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("QueryTabDatabaseContextTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let configuration = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        return ResultSpooler(configuration: configuration)
    }

    private func makeConnectionSession(
        database: String = "master",
        sidebarFocusedDatabase: String? = nil
    ) -> ConnectionSession {
        let session = ConnectionSession(
            connection: TestFixtures.savedConnection(connectionName: "Test Server", database: database),
            session: MockDatabaseSession(),
            spoolManager: makeSpoolManager()
        )
        session.sidebarFocusedDatabase = sidebarFocusedDatabase
        return session
    }

    @Test func connectionDatabaseResolutionPrefersActiveTabDatabase() {
        let databaseName = QueryEditorConnectionContextResolver.resolveDatabaseName(
            tabDatabaseName: "analytics",
            sessionDatabaseName: "master",
            connectionDatabaseName: "defaultdb"
        )

        #expect(databaseName == "analytics")
    }

    @Test func completionStructureReturnsAllDatabases() {
        let structure = DatabaseStructure(
            serverVersion: "16.0",
            databases: [
                DatabaseInfo(name: "master", schemas: [SchemaInfo(name: "dbo", objects: [])]),
                DatabaseInfo(name: "analytics", schemas: [SchemaInfo(name: "sales", objects: [])])
            ]
        )

        let result = QueryEditorConnectionContextResolver.completionStructure(
            from: structure,
            selectedDatabase: "analytics"
        )

        // All databases should be returned for cross-database completion.
        // selectedDatabase only sets the default catalog in EchoSense.
        #expect(result?.databases.count == 2)
        #expect(result?.databases.map(\.name).sorted() == ["analytics", "master"])
    }

    @Test func sessionActiveDatabaseFollowsActiveTab() {
        let session = makeConnectionSession(database: "defaultdb", sidebarFocusedDatabase: "master")
        let firstTab = session.addQueryTab(withQuery: "SELECT 1", database: "master")
        let secondTab = session.addQueryTab(withQuery: "SELECT 2", database: "analytics")

        session.activeQueryTabID = firstTab.id
        #expect(session.activeDatabaseName == "master")

        session.activeQueryTabID = secondTab.id
        #expect(session.activeDatabaseName == "analytics")
    }

    @Test func sessionTracksSchemaLoadsPerDatabase() {
        let session = makeConnectionSession()

        #expect(session.beginSchemaLoad(forDatabase: "analytics") == true)
        #expect(session.beginSchemaLoad(forDatabase: "analytics") == false)
        #expect(session.beginSchemaLoad(forDatabase: "reporting") == true)

        session.finishSchemaLoad(forDatabase: "analytics")

        #expect(session.beginSchemaLoad(forDatabase: "analytics") == true)
    }
}

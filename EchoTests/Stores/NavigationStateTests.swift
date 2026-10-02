import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NavigationState")
struct NavigationStateTests {

    // MARK: - selectProject

    @Test func selectProjectSetsSelectedProject() {
        let state = NavigationState()
        let project = TestFixtures.project(name: "MyProject")

        state.selectProject(project)

        #expect(state.selectedProject?.id == project.id)
        #expect(state.selectedProject?.name == "MyProject")
    }

    @Test func selectProjectClearsDownstreamSelections() {
        let state = NavigationState()
        let project = TestFixtures.project()
        let connection = TestFixtures.savedConnection()

        state.selectedConnection = connection
        state.selectedDatabase = "testdb"

        state.selectProject(project)

        #expect(state.selectedConnection == nil)
        #expect(state.selectedDatabase == nil)
    }

    // MARK: - selectConnection

    @Test func selectConnectionSetsSelectedConnection() {
        let state = NavigationState()
        let connection = TestFixtures.savedConnection(connectionName: "Production")

        state.selectConnection(connection)

        #expect(state.selectedConnection?.id == connection.id)
        #expect(state.selectedConnection?.connectionName == "Production")
    }

    @Test func selectConnectionClearsDatabase() {
        let state = NavigationState()
        state.selectedDatabase = "olddb"

        let connection = TestFixtures.savedConnection()
        state.selectConnection(connection)

        #expect(state.selectedDatabase == nil)
    }

    // MARK: - selectDatabase

    @Test func selectDatabaseSetsSelectedDatabase() {
        let state = NavigationState()
        state.selectDatabase("analytics")

        #expect(state.selectedDatabase == "analytics")
    }

    @Test func selectDatabaseDoesNotClearOtherSelections() {
        let state = NavigationState()
        let connection = TestFixtures.savedConnection()
        state.selectedConnection = connection

        state.selectDatabase("mydb")

        #expect(state.selectedConnection?.id == connection.id)
        #expect(state.selectedDatabase == "mydb")
    }

    // MARK: - navigateBack

    @Test func navigateBackPopsDatabase() {
        let state = NavigationState()
        let connection = TestFixtures.savedConnection()
        state.selectedConnection = connection
        state.selectedDatabase = "testdb"

        state.navigateBack()

        #expect(state.selectedDatabase == nil)
        #expect(state.selectedConnection?.id == connection.id)
    }

    @Test func navigateBackPopsConnection() {
        let state = NavigationState()
        let connection = TestFixtures.savedConnection()
        state.selectedConnection = connection

        state.navigateBack()

        #expect(state.selectedConnection == nil)
    }

    @Test func navigateBackPopsInOrder() {
        let state = NavigationState()
        let connection = TestFixtures.savedConnection()
        state.selectedConnection = connection
        state.selectedDatabase = "testdb"

        // First back: removes database
        state.navigateBack()
        #expect(state.selectedDatabase == nil)
        #expect(state.selectedConnection != nil)

        // Second back: removes connection
        state.navigateBack()
        #expect(state.selectedConnection == nil)
    }

    @Test func navigateBackWithNothingSelectedDoesNothing() {
        let state = NavigationState()
        state.navigateBack()

        #expect(state.selectedProject == nil)
        #expect(state.selectedConnection == nil)
        #expect(state.selectedDatabase == nil)
    }

    // MARK: - reset

    @Test func resetClearsAllExceptProject() {
        let state = NavigationState()
        let project = TestFixtures.project()
        let connection = TestFixtures.savedConnection()

        state.selectedProject = project
        state.selectedConnection = connection
        state.selectedDatabase = "testdb"

        state.reset()

        #expect(state.selectedProject?.id == project.id) // project not cleared by reset
        #expect(state.selectedConnection == nil)
        #expect(state.selectedDatabase == nil)
    }

    // MARK: - breadcrumbs

    @Test func breadcrumbsEmptyWhenNothingSelected() {
        let state = NavigationState()
        #expect(state.breadcrumbs.isEmpty)
    }

    @Test func breadcrumbsWithProjectOnly() {
        let state = NavigationState()
        let project = TestFixtures.project(name: "Dev")
        state.selectedProject = project

        let crumbs = state.breadcrumbs
        #expect(crumbs.count == 1)
        if case .project(let p) = crumbs[0] {
            #expect(p.id == project.id)
        } else {
            Issue.record("Expected project breadcrumb")
        }
    }

    @Test func breadcrumbsWithProjectAndConnection() {
        let state = NavigationState()
        let project = TestFixtures.project()
        let connection = TestFixtures.savedConnection(connectionName: "ProdDB")
        state.selectedProject = project
        state.selectedConnection = connection

        let crumbs = state.breadcrumbs
        #expect(crumbs.count == 2)
    }

    @Test func breadcrumbsWithConnectionAndDatabase() {
        let state = NavigationState()
        let connection = TestFixtures.savedConnection()
        state.selectedConnection = connection
        state.selectedDatabase = "analytics"

        let crumbs = state.breadcrumbs
        #expect(crumbs.count == 2)
        if case .database(let name) = crumbs[1] {
            #expect(name == "analytics")
        } else {
            Issue.record("Expected database breadcrumb")
        }
    }

    @Test func breadcrumbsDatabaseRequiresConnection() {
        let state = NavigationState()
        state.selectedDatabase = "orphandb"

        let crumbs = state.breadcrumbs
        // Database without a connection should not appear
        #expect(crumbs.isEmpty)
    }

    @Test func breadcrumbsFullPath() {
        let state = NavigationState()
        let project = TestFixtures.project()
        let connection = TestFixtures.savedConnection()
        state.selectedProject = project
        state.selectedConnection = connection
        state.selectedDatabase = "analytics"

        let crumbs = state.breadcrumbs
        #expect(crumbs.count == 3)
    }

    // MARK: - NavigationLevel

    @Test func navigationLevelProjectId() {
        let project = TestFixtures.project()
        let level = NavigationLevel.project(project)
        #expect(level.id == "project-\(project.id)")
    }

    @Test func navigationLevelConnectionId() {
        let connection = TestFixtures.savedConnection()
        let level = NavigationLevel.connection(connection)
        #expect(level.id == "connection-\(connection.id)")
    }

    @Test func navigationLevelDatabaseId() {
        let level = NavigationLevel.database("testdb")
        #expect(level.id == "database-testdb")
    }

    @Test func navigationLevelDisplayNameProject() {
        let project = TestFixtures.project(name: "My Project")
        let level = NavigationLevel.project(project)
        #expect(level.displayName == "My Project")
    }

    @Test func navigationLevelDisplayNameConnectionWithName() {
        let connection = TestFixtures.savedConnection(connectionName: "Production")
        let level = NavigationLevel.connection(connection)
        #expect(level.displayName == "Production")
    }

    @Test func navigationLevelDisplayNameConnectionFallsBackToHost() {
        let connection = TestFixtures.savedConnection(connectionName: "", host: "db.example.com")
        let level = NavigationLevel.connection(connection)
        #expect(level.displayName == "db.example.com")
    }

    @Test func navigationLevelDisplayNameDatabase() {
        let level = NavigationLevel.database("analytics")
        #expect(level.displayName == "analytics")
    }

    @Test func navigationLevelIconProject() {
        let project = TestFixtures.project()
        let level = NavigationLevel.project(project)
        #expect(level.icon == "folder.badge.gearshape")
    }

    @Test func navigationLevelIconConnectionPostgres() {
        let connection = TestFixtures.savedConnection(databaseType: .postgresql)
        let level = NavigationLevel.connection(connection)
        #expect(level.icon == DatabaseType.postgresql.iconName)
    }

    @Test func navigationLevelIconConnectionMSSQL() {
        let connection = TestFixtures.savedConnection(databaseType: .microsoftSQL)
        let level = NavigationLevel.connection(connection)
        #expect(level.icon == DatabaseType.microsoftSQL.iconName)
    }

    @Test func navigationLevelIconDatabase() {
        let level = NavigationLevel.database("testdb")
        #expect(level.icon == "cylinder.fill")
    }
}

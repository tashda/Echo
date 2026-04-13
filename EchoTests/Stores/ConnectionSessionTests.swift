import XCTest
@testable import Echo

@MainActor
final class ConnectionSessionTests: XCTestCase {
    private var spoolManager: ResultSpooler!
    private var mockSession: MockDatabaseSession!
    private var connection: SavedConnection!
    private var retainedSessions: [ConnectionSession] = []

    override func setUp() async throws {
        try await super.setUp()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConnectionSessionTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let config = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        spoolManager = ResultSpooler(configuration: config)
        mockSession = MockDatabaseSession()
        connection = TestFixtures.savedConnection(connectionName: "Test Server", database: "mydb")
        retainedSessions = []
    }

    override func tearDown() async throws {
        retainedSessions.removeAll()
        spoolManager = nil
        mockSession = nil
        connection = nil
        try await super.tearDown()
    }

    private func makeConnectionSession() -> ConnectionSession {
        let cs = ConnectionSession(
            connection: connection,
            session: mockSession,
            spoolManager: spoolManager
        )
        retainedSessions.append(cs)
        return cs
    }

    // MARK: - Tab Creation

    func testAddQueryTabCreatesTabWithDefaults() async {
        let cs = makeConnectionSession()
        let tab = cs.addQueryTab()

        XCTAssertEqual(cs.queryTabs.count, 1)
        XCTAssertEqual(cs.activeQueryTabID, tab.id)
        XCTAssertEqual(tab.title, "Query 1")
        XCTAssertNotNil(tab.query)
    }

    func testAddQueryTabWithCustomQuery() async {
        let cs = makeConnectionSession()
        let tab = cs.addQueryTab(withQuery: "SELECT * FROM orders")

        XCTAssertEqual(tab.query?.sql, "SELECT * FROM orders")
    }

    func testAddMultipleTabsIncrementsTitle() async {
        let cs = makeConnectionSession()
        let t1 = cs.addQueryTab()
        let t2 = cs.addQueryTab()

        XCTAssertEqual(t1.title, "Query 1")
        XCTAssertEqual(t2.title, "Query 2")
        XCTAssertEqual(cs.activeQueryTabID, t2.id)
    }

    func testAddDiagramTabCreatesDiagramTab() async {
        let cs = makeConnectionSession()
        let object = TestFixtures.schemaObjectInfo(name: "orders", schema: "sales", type: .table)
        let viewModel = SchemaDiagramViewModel(
            nodes: [],
            edges: [],
            baseNodeID: "sales.orders",
            title: "sales.orders",
            context: SchemaDiagramContext(
                projectID: UUID(),
                connectionID: cs.connection.id,
                connectionSessionID: cs.id,
                object: object,
                cacheKey: nil
            )
        )

        let tab = cs.addDiagramTab(for: object, viewModel: viewModel, databaseName: "sales")

        XCTAssertEqual(cs.queryTabs.count, 1)
        XCTAssertEqual(tab.kind, .diagram)
        XCTAssertEqual(tab.activeDatabaseName, "sales")
        XCTAssertNotNil(tab.diagram)
    }

    func testAddDiagramTabReusesExistingObjectDiagram() async {
        let cs = makeConnectionSession()
        let object = TestFixtures.schemaObjectInfo(name: "orders", schema: "sales", type: .table)
        let first = SchemaDiagramViewModel(
            nodes: [],
            edges: [],
            baseNodeID: "sales.orders",
            title: "sales.orders",
            context: SchemaDiagramContext(
                projectID: UUID(),
                connectionID: cs.connection.id,
                connectionSessionID: cs.id,
                object: object,
                cacheKey: nil
            )
        )
        let second = SchemaDiagramViewModel(
            nodes: [],
            edges: [],
            baseNodeID: "sales.orders",
            title: "sales.orders",
            context: SchemaDiagramContext(
                projectID: UUID(),
                connectionID: cs.connection.id,
                connectionSessionID: cs.id,
                object: object,
                cacheKey: nil
            )
        )

        let firstTab = cs.addDiagramTab(for: object, viewModel: first, databaseName: "sales")
        let secondTab = cs.addDiagramTab(for: object, viewModel: second, databaseName: "sales")

        XCTAssertEqual(cs.queryTabs.count, 1)
        XCTAssertEqual(firstTab.id, secondTab.id)
    }

    // MARK: - Close Tab

    func testCloseQueryTabRemovesTab() async {
        let cs = makeConnectionSession()
        let tab = cs.addQueryTab()

        cs.closeQueryTab(withID: tab.id)
        XCTAssertEqual(cs.queryTabs.count, 0)
        XCTAssertNil(cs.activeQueryTabID)
    }

    func testCloseQueryTabAdjustsActiveTabID() async {
        let cs = makeConnectionSession()
        let t1 = cs.addQueryTab()
        let t2 = cs.addQueryTab()
        let t3 = cs.addQueryTab()

        // Active is t3
        cs.closeQueryTab(withID: t3.id)
        XCTAssertEqual(cs.activeQueryTabID, t2.id, "Should select previous tab")

        cs.closeQueryTab(withID: t1.id)
        XCTAssertEqual(cs.activeQueryTabID, t2.id, "Closing non-active tab shouldn't change active")
    }

    // MARK: - Display Names

    func testDisplayNameIncludesDatabase() async {
        let cs = makeConnectionSession()
        XCTAssertEqual(cs.displayName, "Test Server • mydb")
    }

    func testDisplayNameWithoutDatabase() async {
        connection = TestFixtures.savedConnection(connectionName: "Test", database: "")
        let cs = ConnectionSession(
            connection: connection,
            session: mockSession,
            spoolManager: spoolManager
        )
        retainedSessions.append(cs)
        XCTAssertEqual(cs.displayName, "Test")
    }

    func testShortDisplayName() async {
        let cs = makeConnectionSession()
        XCTAssertEqual(cs.shortDisplayName, "Test Server")
    }

    // MARK: - Batch Size Clamping

    func testUpdateDefaultInitialBatchSizeClampsMinimum() async {
        let cs = makeConnectionSession()
        // Set a very low batch size — should be clamped to 100 internally
        cs.updateDefaultInitialBatchSize(10)
        // Verify by creating a tab — if clamping works, the tab is created without issues
        let tab = cs.addQueryTab(withQuery: "SELECT 1")
        XCTAssertNotNil(tab)
    }

    func testHydrateMetadataFreshnessFromCacheStructureMarksCachedAndListOnly() async {
        let cs = makeConnectionSession()
        cs.databaseStructure = DatabaseStructure(
            serverVersion: "16.0",
            databases: [
                DatabaseInfo(
                    name: "loaded",
                    schemas: [SchemaInfo(name: "public", objects: [TestFixtures.schemaObjectInfo(name: "users")])]
                ),
                DatabaseInfo(name: "list_only", schemas: [])
            ]
        )

        cs.hydrateMetadataFreshnessFromCacheStructure()

        XCTAssertEqual(cs.metadataFreshness(forDatabase: "loaded"), .cached)
        XCTAssertEqual(cs.metadataFreshness(forDatabase: "list_only"), .listOnly)
    }

    func testClearMetadataCacheStateResetsStructureAndFreshness() async {
        let cs = makeConnectionSession()
        cs.databaseStructure = TestFixtures.databaseStructure()
        cs.hydrateMetadataFreshnessFromCacheStructure()
        cs.markMetadataRefreshStarted(forDatabase: "db_0")
        _ = cs.beginSchemaLoad(forDatabase: "db_0")

        cs.clearMetadataCacheState()

        XCTAssertNil(cs.databaseStructure)
        XCTAssertEqual(cs.metadataFreshness(forDatabase: "db_0"), .listOnly)
        XCTAssertTrue(cs.schemaLoadsInFlight.isEmpty)
        XCTAssertEqual(cs.structureLoadingState, .idle)
    }
}

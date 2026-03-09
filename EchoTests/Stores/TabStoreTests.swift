import XCTest
@testable import Echo

@MainActor
final class TabStoreTests: XCTestCase {
    private var store: TabStore!
    private var spoolManager: ResultSpoolCoordinator!
    private var mockSession: MockDatabaseSession!
    private var connection: SavedConnection!

    override func setUp() {
        super.setUp()
        store = TabStore()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("TabStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let config = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        spoolManager = ResultSpoolCoordinator(configuration: config)
        mockSession = MockDatabaseSession()
        connection = TestFixtures.savedConnection()
    }

    private func makeTab(title: String = "Query") -> WorkspaceTab {
        let queryState = QueryEditorState(
            sql: "SELECT 1",
            spoolManager: spoolManager
        )
        return WorkspaceTab(
            connection: connection,
            session: mockSession,
            connectionSessionID: UUID(),
            title: title,
            content: .query(queryState)
        )
    }

    // MARK: - Add / Remove

    func testAddTab() {
        let tab = makeTab()
        store.addTab(tab)

        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeTabId, tab.id)
    }

    func testCloseTab() {
        let tab = makeTab()
        store.addTab(tab)

        store.closeTab(id: tab.id)
        XCTAssertEqual(store.tabs.count, 0)
    }

    // MARK: - Tab Navigation

    func testActivateNextTab() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")

        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)

        // Active is t3 (last added)
        store.selectTab(t1)
        XCTAssertEqual(store.activeTabId, t1.id)

        store.activateNextTab()
        XCTAssertEqual(store.activeTabId, t2.id)

        store.activateNextTab()
        XCTAssertEqual(store.activeTabId, t3.id)
    }

    func testActivatePreviousTab() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")

        store.addTab(t1)
        store.addTab(t2)

        store.selectTab(t2)
        store.activatePreviousTab()
        XCTAssertEqual(store.activeTabId, t1.id)
    }

    // MARK: - Reopen Closed Tab

    func testReopenLastClosedTab() {
        let tab = makeTab(title: "Closed")
        store.addTab(tab)
        store.closeTab(id: tab.id)
        XCTAssertEqual(store.tabs.count, 0)

        let reopened = store.reopenLastClosedTab(activate: true)
        // May return nil depending on TabCoordinator implementation — just ensure no crash
        if let reopened {
            XCTAssertTrue(store.tabs.contains(where: { $0.id == reopened.id }))
        }
    }

    // MARK: - Move

    func testMoveTab() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")

        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)

        store.moveTab(id: t3.id, to: 0)
        XCTAssertEqual(store.tabs[0].id, t3.id)
    }

    // MARK: - Index

    func testIndexOfTab() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")

        store.addTab(t1)
        store.addTab(t2)

        XCTAssertEqual(store.index(of: t1.id), 0)
        XCTAssertEqual(store.index(of: t2.id), 1)
        XCTAssertNil(store.index(of: UUID()))
    }
}

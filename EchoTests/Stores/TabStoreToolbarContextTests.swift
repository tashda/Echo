import Foundation
import Observation
import Synchronization
import Testing
@testable import Echo

@MainActor
@Suite("Tab store toolbar context")
struct TabStoreToolbarContextTests {
    private func makeQueryTab(in store: TabStore) -> WorkspaceTab {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TabStoreToolbarContextTests-\(UUID().uuidString)")
        let spooler = ResultSpooler(configuration: ResultSpoolConfiguration.defaultConfiguration(rootDirectory: root))
        let tab = WorkspaceTab(
            connection: TestFixtures.savedConnection(),
            session: MockDatabaseSession(),
            connectionSessionID: UUID(),
            title: "Query",
            content: .query(QueryEditorState(sql: "SELECT 1", spoolManager: spooler))
        )
        store.addTab(tab)
        return tab
    }

    @Test func followsTheActiveTabAFrameLater() async {
        let store = TabStore()
        #expect(!store.activeTabToolbarContext.isQuery)
        _ = makeQueryTab(in: store)
        await Task.yield()
        await Task.yield()
        #expect(store.activeTabToolbarContext.isQuery)
        #expect(store.activeTabKind == .query)
    }

    /// Switching between tabs that need the same toolbar must not touch the context, or the
    /// toolbar's content is rebuilt on every switch.
    @Test func switchingBetweenAlikeTabsLeavesTheContextAlone() async {
        let store = TabStore()
        let first = makeQueryTab(in: store)
        _ = makeQueryTab(in: store)
        await Task.yield()
        await Task.yield()
        let changed = Mutex(false)
        withObservationTracking {
            _ = store.activeTabToolbarContext
        } onChange: {
            changed.withLock { $0 = true }
        }
        store.selectTab(first)
        await Task.yield()
        await Task.yield()
        #expect(store.activeTabId == first.id)
        #expect(!changed.withLock { $0 })
    }
}

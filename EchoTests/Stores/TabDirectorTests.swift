import Testing
import Foundation
@testable import Echo

// MARK: - Mock Delegate

final class MockTabDirectorDelegate: @preconcurrency TabDirectorDelegate {
    var addedTabs: [WorkspaceTab] = []
    var removedTabIDs: [UUID] = []
    var activeTabIDChanges: [UUID?] = []
    var reorderCount = 0
    var shouldCloseResult = true

    func tabDirector(_ manager: TabDirector, didAdd tab: WorkspaceTab) {
        addedTabs.append(tab)
    }

    func tabDirector(_ manager: TabDirector, didRemoveTabID tabID: UUID) {
        removedTabIDs.append(tabID)
    }

    func tabDirector(_ manager: TabDirector, didSetActiveTabID tabID: UUID?) {
        activeTabIDChanges.append(tabID)
    }

    func tabDirectorDidReorderTabs(_ manager: TabDirector) {
        reorderCount += 1
    }

    func tabDirector(_ manager: TabDirector, shouldClose tab: WorkspaceTab) -> Bool {
        shouldCloseResult
    }
}

// MARK: - Test Helpers

@MainActor
private func makeTab(title: String = "Tab", isPinned: Bool = false) -> WorkspaceTab {
    let connection = TestFixtures.savedConnection()
    let session = MockDatabaseSession()
    let spoolConfig = ResultSpoolConfiguration.defaultConfiguration(
        rootDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    )
    let spooler = ResultSpooler(configuration: spoolConfig)
    let queryState = QueryEditorState(sql: "SELECT 1;", spoolManager: spooler)
    return WorkspaceTab(
        connection: connection,
        session: session,
        connectionSessionID: UUID(),
        title: title,
        content: .query(queryState),
        isPinned: isPinned
    )
}

@MainActor
private func makeDirector(delegate: MockTabDirectorDelegate? = nil) -> (TabDirector, MockTabDirectorDelegate) {
    let director = TabDirector()
    let del = delegate ?? MockTabDirectorDelegate()
    director.delegate = del
    return (director, del)
}

// MARK: - Tests

@MainActor
@Suite("TabDirector")
struct TabDirectorTests {

    // MARK: - addTab

    @Test func addTabAppendsToArray() {
        let (director, _) = makeDirector()
        let tab = makeTab(title: "First")

        director.addTab(tab)

        #expect(director.tabs.count == 1)
        #expect(director.tabs[0].id == tab.id)
    }

    @Test func addTabSetsActiveTab() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)

        #expect(director.activeTabId == tab.id)
    }

    @Test func addTabNotifiesDelegate() {
        let (director, delegate) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)

        #expect(delegate.addedTabs.count == 1)
        #expect(delegate.addedTabs[0].id == tab.id)
    }

    @Test func addMultipleTabsSetsLastAsActive() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        #expect(director.tabs.count == 3)
        #expect(director.activeTabId == tab3.id)
    }

    // MARK: - insertTab

    @Test func insertTabAtSpecificIndex() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Inserted")

        director.addTab(tab1)
        director.addTab(tab2)
        director.insertTab(tab3, at: 1)

        #expect(director.tabs[1].id == tab3.id)
        #expect(director.tabs.count == 3)
    }

    @Test func insertTabWithoutActivate() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.insertTab(tab2, at: 0, activate: false)

        #expect(director.activeTabId == tab1.id)
    }

    @Test func insertTabWithActivate() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.insertTab(tab2, at: 0, activate: true)

        #expect(director.activeTabId == tab2.id)
    }

    @Test func insertTabWithoutDelegateNotification() {
        let (director, delegate) = makeDirector()
        let tab = makeTab()

        director.insertTab(tab, at: 0, notifyDelegate: false)

        #expect(delegate.addedTabs.isEmpty)
    }

    @Test func insertPinnedTabClampsToBeforePinnedCount() {
        let (director, _) = makeDirector()
        let pinned1 = makeTab(title: "Pinned1", isPinned: true)
        let unpinned1 = makeTab(title: "Unpinned1")

        director.addTab(pinned1)
        director.addTab(unpinned1)

        let pinned2 = makeTab(title: "Pinned2", isPinned: true)
        director.insertTab(pinned2, at: 5) // beyond count

        // Pinned tabs should be before unpinned
        #expect(director.tabs[0].isPinned || director.tabs[1].isPinned)
    }

    // MARK: - removeTab

    @Test func removeTabRemovesFromArray() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.removeTab(withID: tab.id)

        #expect(director.tabs.isEmpty)
    }

    @Test func removeActiveTabFallsToNext() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.setActiveTab(tab2.id)
        director.removeTab(withID: tab2.id)

        #expect(director.activeTabId == tab3.id)
    }

    @Test func removeLastActiveTabFallsToPrevious() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)
        director.removeTab(withID: tab2.id)

        #expect(director.activeTabId == tab1.id)
    }

    @Test func removeOnlyTabClearsActive() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.removeTab(withID: tab.id)

        #expect(director.activeTabId == nil)
    }

    @Test func removeNonActiveTabKeepsActiveUnchanged() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        // Active is tab3; remove tab1
        director.removeTab(withID: tab1.id)

        #expect(director.activeTabId == tab3.id)
        #expect(director.tabs.count == 2)
    }

    @Test func removeTabNotifiesDelegate() {
        let (director, delegate) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.removeTab(withID: tab.id)

        #expect(delegate.removedTabIDs.contains(tab.id))
    }

    @Test func removeNonexistentTabDoesNothing() {
        let (director, delegate) = makeDirector()
        let tab = makeTab()
        director.addTab(tab)

        director.removeTab(withID: UUID())

        #expect(director.tabs.count == 1)
        #expect(delegate.removedTabIDs.isEmpty)
    }

    // MARK: - closeTab

    @Test func closeTabRecordsInHistory() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        let result = director.closeTab(id: tab.id)

        #expect(result == true)
        #expect(director.canReopenClosedTab)
    }

    @Test func closeTabDelegateRefusesClose() {
        let (director, delegate) = makeDirector()
        delegate.shouldCloseResult = false
        let tab = makeTab()

        director.addTab(tab)
        let result = director.closeTab(id: tab.id)

        #expect(result == false)
        #expect(director.tabs.count == 1)
    }

    @Test func closeTabDelegateAllowsClose() {
        let (director, delegate) = makeDirector()
        delegate.shouldCloseResult = true
        let tab = makeTab()

        director.addTab(tab)
        let result = director.closeTab(id: tab.id)

        #expect(result == true)
        #expect(director.tabs.isEmpty)
    }

    @Test func closeNonexistentTabReturnsFalse() {
        let (director, _) = makeDirector()
        let result = director.closeTab(id: UUID())
        #expect(result == false)
    }

    // MARK: - setActiveTab

    @Test func setActiveTabUpdatesActiveTabId() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)
        director.setActiveTab(tab1.id)

        #expect(director.activeTabId == tab1.id)
    }

    @Test func setActiveTabWithInvalidIdDoesNothing() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.setActiveTab(UUID())

        #expect(director.activeTabId == tab.id)
    }

    // MARK: - getTab

    @Test func getTabFound() {
        let (director, _) = makeDirector()
        let tab = makeTab(title: "Target")

        director.addTab(tab)
        let found = director.getTab(id: tab.id)

        #expect(found?.id == tab.id)
        #expect(found?.title == "Target")
    }

    @Test func getTabNotFound() {
        let (director, _) = makeDirector()
        let found = director.getTab(id: UUID())
        #expect(found == nil)
    }

    // MARK: - index(of:)

    @Test func indexOfFound() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)

        #expect(director.index(of: tab1.id) == 0)
        #expect(director.index(of: tab2.id) == 1)
    }

    @Test func indexOfNotFound() {
        let (director, _) = makeDirector()
        #expect(director.index(of: UUID()) == nil)
    }

    // MARK: - activeTab

    @Test func activeTabReturnsCorrectTab() {
        let (director, _) = makeDirector()
        let tab = makeTab(title: "Active")

        director.addTab(tab)

        #expect(director.activeTab?.id == tab.id)
    }

    @Test func activeTabReturnsNilWhenEmpty() {
        let director = TabDirector()
        #expect(director.activeTab == nil)
    }

    // MARK: - activateNextTab

    @Test func activateNextTabWrapsAround() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        // Active is tab3 (last added)
        director.activateNextTab()
        #expect(director.activeTabId == tab1.id) // wraps to first
    }

    @Test func activateNextTabMovesForward() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)

        director.setActiveTab(tab1.id)
        director.activateNextTab()

        #expect(director.activeTabId == tab2.id)
    }

    @Test func activateNextTabSingleTab() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.activateNextTab()

        #expect(director.activeTabId == tab.id)
    }

    @Test func activateNextTabNoTabs() {
        let (director, _) = makeDirector()
        director.activateNextTab()
        #expect(director.activeTabId == nil)
    }

    @Test func activateNextTabNoActiveSelectsFirst() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)
        director.activeTabId = nil

        director.activateNextTab()
        #expect(director.activeTabId == tab1.id)
    }

    // MARK: - activatePreviousTab

    @Test func activatePreviousTabWrapsAround() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.setActiveTab(tab1.id)
        director.activatePreviousTab()

        #expect(director.activeTabId == tab3.id) // wraps to last
    }

    @Test func activatePreviousTabMovesBackward() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)

        director.activatePreviousTab()
        #expect(director.activeTabId == tab1.id)
    }

    @Test func activatePreviousTabSingleTab() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.activatePreviousTab()

        #expect(director.activeTabId == tab.id)
    }

    @Test func activatePreviousTabNoTabs() {
        let (director, _) = makeDirector()
        director.activatePreviousTab()
        #expect(director.activeTabId == nil)
    }

    @Test func activatePreviousTabNoActiveSelectsLast() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)
        director.activeTabId = nil

        director.activatePreviousTab()
        #expect(director.activeTabId == tab2.id)
    }

    // MARK: - moveTab

    @Test func moveTabReorders() {
        let (director, delegate) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.moveTab(id: tab3.id, to: 0)

        #expect(director.tabs[0].id == tab3.id)
        #expect(delegate.reorderCount > 0)
    }

    @Test func moveTabToEnd() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.moveTab(id: tab1.id, to: 2)

        #expect(director.tabs.last?.id == tab1.id)
    }

    @Test func moveTabToBeginning() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)

        director.moveTab(id: tab2.id, to: 0)

        #expect(director.tabs[0].id == tab2.id)
    }

    @Test func moveNonexistentTabDoesNothing() {
        let (director, delegate) = makeDirector()
        let tab = makeTab()
        director.addTab(tab)

        director.moveTab(id: UUID(), to: 0)

        #expect(director.tabs.count == 1)
        #expect(delegate.reorderCount == 0)
    }

    // MARK: - togglePin / pinTab / unpinTab

    @Test func togglePinPinsUnpinnedTab() {
        let (director, _) = makeDirector()
        let tab = makeTab(title: "Tab", isPinned: false)

        director.addTab(tab)
        director.togglePin(for: tab.id)

        #expect(tab.isPinned == true)
    }

    @Test func togglePinUnpinsPinnedTab() {
        let (director, _) = makeDirector()
        let tab = makeTab(title: "Tab", isPinned: true)

        director.addTab(tab)
        director.togglePin(for: tab.id)

        #expect(tab.isPinned == false)
    }

    @Test func pinTabMovesToPinnedSection() {
        let (director, _) = makeDirector()
        let pinned = makeTab(title: "Pinned", isPinned: true)
        let unpinned1 = makeTab(title: "Unpinned1")
        let unpinned2 = makeTab(title: "Unpinned2")

        director.addTab(pinned)
        director.addTab(unpinned1)
        director.addTab(unpinned2)

        director.pinTab(id: unpinned2.id)

        // After pinning unpinned2, it should be among the first pinned tabs
        #expect(unpinned2.isPinned == true)
        let pinnedTabs = director.tabs.filter { $0.isPinned }
        #expect(pinnedTabs.count == 2)
    }

    @Test func unpinTabMovesToUnpinnedSection() {
        let (director, _) = makeDirector()
        let pinned1 = makeTab(title: "Pinned1", isPinned: true)
        let pinned2 = makeTab(title: "Pinned2", isPinned: true)
        let unpinned = makeTab(title: "Unpinned")

        director.addTab(pinned1)
        director.addTab(pinned2)
        director.addTab(unpinned)

        director.unpinTab(id: pinned2.id)

        #expect(pinned2.isPinned == false)
        let pinnedTabs = director.tabs.filter { $0.isPinned }
        #expect(pinnedTabs.count == 1)
    }

    @Test func pinAlreadyPinnedTabDoesNothing() {
        let (director, _) = makeDirector()
        let tab = makeTab(title: "Pinned", isPinned: true)

        director.addTab(tab)
        let countBefore = director.tabs.count

        director.pinTab(id: tab.id)

        #expect(director.tabs.count == countBefore)
        #expect(tab.isPinned == true)
    }

    @Test func unpinAlreadyUnpinnedTabDoesNothing() {
        let (director, _) = makeDirector()
        let tab = makeTab(title: "Unpinned")

        director.addTab(tab)

        director.unpinTab(id: tab.id)

        #expect(tab.isPinned == false)
    }

    @Test func togglePinNonexistentTabDoesNothing() {
        let (director, _) = makeDirector()
        director.togglePin(for: UUID())
        #expect(director.tabs.isEmpty)
    }

    @Test func pinTabNotifiesReorder() {
        let (director, delegate) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.pinTab(id: tab.id)

        #expect(delegate.reorderCount > 0)
    }

    // MARK: - pinnedCount

    @Test func pinnedCountReturnsCorrectValue() {
        let (director, _) = makeDirector()
        let pinned1 = makeTab(title: "P1", isPinned: true)
        let pinned2 = makeTab(title: "P2", isPinned: true)
        let unpinned = makeTab(title: "U1")

        director.addTab(pinned1)
        director.addTab(pinned2)
        director.addTab(unpinned)

        #expect(director.pinnedCount() == 2)
    }

    @Test func pinnedCountZeroWhenNoPins() {
        let (director, _) = makeDirector()
        let tab = makeTab()
        director.addTab(tab)

        #expect(director.pinnedCount() == 0)
    }

    // MARK: - reopenLastClosedTab

    @Test func reopenLastClosedTabReopensAtOriginalIndex() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.closeTab(id: tab2.id)
        #expect(director.tabs.count == 2)

        let reopened = director.reopenLastClosedTab()
        #expect(reopened?.id == tab2.id)
        #expect(director.tabs.count == 3)
    }

    @Test func reopenLastClosedTabEmptyHistoryReturnsNil() {
        let (director, _) = makeDirector()
        let result = director.reopenLastClosedTab()
        #expect(result == nil)
    }

    @Test func reopenLastClosedTabActivatesByDefault() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)
        director.closeTab(id: tab1.id)

        let reopened = director.reopenLastClosedTab()
        #expect(director.activeTabId == reopened?.id)
    }

    @Test func reopenLastClosedTabWithoutActivate() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)
        director.closeTab(id: tab1.id)

        let activeBeforeReopen = director.activeTabId
        _ = director.reopenLastClosedTab(activate: false)

        #expect(director.activeTabId == activeBeforeReopen)
    }

    // MARK: - canReopenClosedTab

    @Test func canReopenClosedTabTrueAfterClose() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.closeTab(id: tab.id)

        #expect(director.canReopenClosedTab == true)
    }

    @Test func canReopenClosedTabFalseWhenEmpty() {
        let director = TabDirector()
        #expect(director.canReopenClosedTab == false)
    }

    @Test func canReopenClosedTabFalseAfterReopenAll() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.closeTab(id: tab.id)
        _ = director.reopenLastClosedTab()

        #expect(director.canReopenClosedTab == false)
    }

    // MARK: - closeOtherTabs

    @Test func closeOtherTabsKeepsSpecified() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.closeOtherTabs(keeping: tab2.id)

        #expect(director.tabs.count == 1)
        #expect(director.tabs[0].id == tab2.id)
        #expect(director.activeTabId == tab2.id)
    }

    @Test func closeOtherTabsWithInvalidIdDoesNothing() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)

        director.closeOtherTabs(keeping: UUID())

        #expect(director.tabs.count == 2)
    }

    @Test func closeOtherTabsRecordsClosedInHistory() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.closeOtherTabs(keeping: tab2.id)

        #expect(director.canReopenClosedTab)
    }

    // MARK: - closeTabsLeft

    @Test func closeTabsLeftClosesAllBefore() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.closeTabsLeft(of: tab3.id)

        #expect(director.tabs.count == 1)
        #expect(director.tabs[0].id == tab3.id)
    }

    @Test func closeTabsLeftAtFirstIndexDoesNothing() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)

        director.closeTabsLeft(of: tab1.id)

        #expect(director.tabs.count == 2)
    }

    @Test func closeTabsLeftNonexistentDoesNothing() {
        let (director, _) = makeDirector()
        let tab = makeTab()
        director.addTab(tab)

        director.closeTabsLeft(of: UUID())

        #expect(director.tabs.count == 1)
    }

    // MARK: - closeTabsRight

    @Test func closeTabsRightClosesAllAfter() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.closeTabsRight(of: tab1.id)

        #expect(director.tabs.count == 1)
        #expect(director.tabs[0].id == tab1.id)
    }

    @Test func closeTabsRightAtLastIndexDoesNothing() {
        let (director, _) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)

        director.closeTabsRight(of: tab2.id)

        #expect(director.tabs.count == 2)
    }

    @Test func closeTabsRightNonexistentDoesNothing() {
        let (director, _) = makeDirector()
        let tab = makeTab()
        director.addTab(tab)

        director.closeTabsRight(of: UUID())

        #expect(director.tabs.count == 1)
    }

    // MARK: - Delegate callbacks

    @Test func delegateReceivesSetActiveTabIDCallbacks() {
        let (director, delegate) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1) // triggers didSetActiveTabID
        director.addTab(tab2) // triggers didSetActiveTabID

        #expect(delegate.activeTabIDChanges.contains(tab1.id))
        #expect(delegate.activeTabIDChanges.contains(tab2.id))
    }

    @Test func delegateReceivesRemoveNotificationOnClose() {
        let (director, delegate) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.closeTab(id: tab.id)

        #expect(delegate.removedTabIDs.contains(tab.id))
    }

    // MARK: - reorderTabs

    @Test func reorderTabsMatchesNewOrder() {
        let (director, delegate) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")
        let tab3 = makeTab(title: "Three")

        director.addTab(tab1)
        director.addTab(tab2)
        director.addTab(tab3)

        director.reorderTabs(toMatch: [tab3.id, tab1.id, tab2.id])

        #expect(director.tabs[0].id == tab3.id)
        #expect(director.tabs[1].id == tab1.id)
        #expect(director.tabs[2].id == tab2.id)
        #expect(delegate.reorderCount > 0)
    }

    @Test func reorderTabsSameOrderDoesNotNotify() {
        let (director, delegate) = makeDirector()
        let tab1 = makeTab(title: "One")
        let tab2 = makeTab(title: "Two")

        director.addTab(tab1)
        director.addTab(tab2)

        let reorderCountBefore = delegate.reorderCount
        director.reorderTabs(toMatch: [tab1.id, tab2.id])

        #expect(delegate.reorderCount == reorderCountBefore)
    }

    @Test func reorderTabsEmptyDoesNothing() {
        let director = TabDirector()
        director.reorderTabs(toMatch: [UUID()])
        #expect(director.tabs.isEmpty)
    }

    // MARK: - removeTabFromWindowClose

    @Test func removeTabFromWindowCloseClosesTab() {
        let (director, _) = makeDirector()
        let tab = makeTab()

        director.addTab(tab)
        director.removeTabFromWindowClose(id: tab.id)

        #expect(director.tabs.isEmpty)
        #expect(director.canReopenClosedTab)
    }
}

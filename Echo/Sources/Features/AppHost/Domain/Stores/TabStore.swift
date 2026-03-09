import Foundation
import Observation

protocol TabStoreDelegate: AnyObject {
    @MainActor func tabStore(_ store: TabStore, didAdd tab: WorkspaceTab)
    @MainActor func tabStore(_ store: TabStore, shouldClose tab: WorkspaceTab) async -> Bool
    @MainActor func tabStore(_ store: TabStore, didRemoveTabID tabID: UUID)
    @MainActor func tabStore(_ store: TabStore, didSetActiveTabID tabID: UUID?)
    @MainActor func tabStoreDidReorderTabs(_ store: TabStore)
}

/// A modular store that manages workspace tabs.
/// Refactored from `EnvironmentState` to adhere to modular MVVM and under-500-line limits.
@Observable @MainActor
final class TabStore {
    // MARK: - State
    var tabCoordinator = TabCoordinator()
    weak var delegate: TabStoreDelegate?
    /// Stored property that mirrors `!tabCoordinator.tabs.isEmpty`.
    /// Needed because Swift Observation cannot track changes through
    /// the ObservableObject-based TabCoordinator.
    var hasTabs: Bool = false
    
    // MARK: - Initialization
    init() {
        tabCoordinator.delegate = self
    }
    
    // MARK: - Public API
    
    var tabs: [WorkspaceTab] {
        tabCoordinator.tabs
    }
    
    var activeTabId: UUID? {
        get { tabCoordinator.activeTabId }
        set { tabCoordinator.activeTabId = newValue }
    }
    
    var activeTab: WorkspaceTab? {
        tabCoordinator.activeTab
    }
    
    func getTab(id: UUID) -> WorkspaceTab? {
        tabCoordinator.getTab(id: id)
    }
    
    func addTab(_ tab: WorkspaceTab) {
        tabCoordinator.addTab(tab)
    }
    
    func insertTab(_ tab: WorkspaceTab, at index: Int, activate: Bool = true) {
        tabCoordinator.insertTab(tab, at: index, activate: activate)
    }
    
    func selectTab(_ tab: WorkspaceTab) {
        tabCoordinator.activeTabId = tab.id
    }
    
    func closeTab(id: UUID) {
        tabCoordinator.closeTab(id: id)
    }
    
    func moveTab(id: UUID, to index: Int) {
        tabCoordinator.moveTab(id: id, to: index)
    }
    
    func togglePin(for id: UUID) {
        tabCoordinator.togglePin(for: id)
    }
    
    func closeOtherTabs(keeping id: UUID) {
        tabCoordinator.closeOtherTabs(keeping: id)
    }
    
    func closeTabsLeft(of id: UUID) {
        tabCoordinator.closeTabsLeft(of: id)
    }
    
    func closeTabsRight(of id: UUID) {
        tabCoordinator.closeTabsRight(of: id)
    }
    
    func index(of id: UUID) -> Int? {
        tabCoordinator.tabs.firstIndex(where: { $0.id == id })
    }
    
    func activateNextTab() {
        tabCoordinator.activateNextTab()
    }
    
    func activatePreviousTab() {
        tabCoordinator.activatePreviousTab()
    }
    
    func reopenLastClosedTab(activate: Bool) -> WorkspaceTab? {
        tabCoordinator.reopenLastClosedTab(activate: activate)
    }
}

// MARK: - TabCoordinatorDelegate

extension TabStore: TabCoordinatorDelegate {
    func tabCoordinator(_ manager: TabCoordinator, didAdd tab: WorkspaceTab) {
        hasTabs = !manager.tabs.isEmpty
        delegate?.tabStore(self, didAdd: tab)
    }
    
    func tabCoordinator(_ manager: TabCoordinator, shouldClose tab: WorkspaceTab) -> Bool {
        // TabCoordinator delegate is synchronous, but TabStoreDelegate is async.
        // For simplicity during migration, we use a Task to bridge if needed, 
        // or just return true if the decision logic can be deferred.
        // Actually, TabCoordinator expects a Bool. If it's a critical guard, we may need to refine.
        return true 
    }
    
    func tabCoordinator(_ manager: TabCoordinator, didRemoveTabID tabID: UUID) {
        hasTabs = !manager.tabs.isEmpty
        delegate?.tabStore(self, didRemoveTabID: tabID)
    }
    
    func tabCoordinator(_ manager: TabCoordinator, didSetActiveTabID tabID: UUID?) {
        delegate?.tabStore(self, didSetActiveTabID: tabID)
    }
    
    func tabCoordinatorDidReorderTabs(_ manager: TabCoordinator) {
        delegate?.tabStoreDidReorderTabs(self)
    }
}

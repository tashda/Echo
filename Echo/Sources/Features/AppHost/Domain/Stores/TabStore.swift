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
///
/// `TabDirector` is an `ObservableObject` whose `@Published` changes are
/// invisible to views that observe `TabStore` via `@Observable` / `@Environment`.
/// To bridge the two observation systems, every piece of state that views depend
/// on is stored here as a plain stored property and kept in sync through the
/// `TabDirectorDelegate` callbacks.
@Observable @MainActor
final class TabStore {
    // MARK: - State

    var tabDirector = TabDirector()
    weak var delegate: TabStoreDelegate?

    /// Stored properties mirroring `TabDirector` so `@Observable` can track them.
    private(set) var tabs: [WorkspaceTab] = []
    var hasTabs: Bool = false
    private var _activeTabId: UUID?

    // MARK: - Initialization

    init() {
        tabDirector.delegate = self
    }

    // MARK: - Public API

    var activeTabId: UUID? {
        get { _activeTabId }
        set {
            guard _activeTabId != newValue else { return }
            _activeTabId = newValue
            tabDirector.activeTabId = newValue
        }
    }

    var activeTab: WorkspaceTab? {
        guard let id = _activeTabId else { return nil }
        return tabs.first { $0.id == id }
    }

    func getTab(id: UUID) -> WorkspaceTab? {
        tabs.first { $0.id == id }
    }

    func addTab(_ tab: WorkspaceTab) {
        tabDirector.addTab(tab)
    }

    func insertTab(_ tab: WorkspaceTab, at index: Int, activate: Bool = true) {
        tabDirector.insertTab(tab, at: index, activate: activate)
    }

    func selectTab(_ tab: WorkspaceTab) {
        tabDirector.activeTabId = tab.id
    }

    func closeTab(id: UUID) {
        tabDirector.closeTab(id: id)
    }

    func moveTab(id: UUID, to index: Int) {
        tabDirector.moveTab(id: id, to: index)
    }

    func togglePin(for id: UUID) {
        tabDirector.togglePin(for: id)
    }

    func closeOtherTabs(keeping id: UUID) {
        tabDirector.closeOtherTabs(keeping: id)
    }

    func closeTabsLeft(of id: UUID) {
        tabDirector.closeTabsLeft(of: id)
    }

    func closeTabsRight(of id: UUID) {
        tabDirector.closeTabsRight(of: id)
    }

    func index(of id: UUID) -> Int? {
        tabs.firstIndex(where: { $0.id == id })
    }

    func activateNextTab() {
        tabDirector.activateNextTab()
    }

    func activatePreviousTab() {
        tabDirector.activatePreviousTab()
    }

    func reopenLastClosedTab(activate: Bool) -> WorkspaceTab? {
        tabDirector.reopenLastClosedTab(activate: activate)
    }

    // MARK: - Internal Sync

    private func syncTabs() {
        tabs = tabDirector.tabs
        hasTabs = !tabs.isEmpty
    }
}

// MARK: - TabDirectorDelegate

extension TabStore: TabDirectorDelegate {
    func tabDirector(_ manager: TabDirector, didAdd tab: WorkspaceTab) {
        syncTabs()
        delegate?.tabStore(self, didAdd: tab)
    }

    func tabDirector(_ manager: TabDirector, shouldClose tab: WorkspaceTab) -> Bool {
        true
    }

    func tabDirector(_ manager: TabDirector, didRemoveTabID tabID: UUID) {
        syncTabs()
        delegate?.tabStore(self, didRemoveTabID: tabID)
    }

    func tabDirector(_ manager: TabDirector, didSetActiveTabID tabID: UUID?) {
        if _activeTabId != tabID {
            _activeTabId = tabID
        }
        delegate?.tabStore(self, didSetActiveTabID: tabID)
    }

    func tabDirectorDidReorderTabs(_ manager: TabDirector) {
        syncTabs()
        delegate?.tabStoreDidReorderTabs(self)
    }
}

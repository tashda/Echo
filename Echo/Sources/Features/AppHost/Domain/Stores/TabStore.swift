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
/// `TabDirector` is `@Observable` and manages the underlying tab array. `TabStore`
/// mirrors `TabDirector`'s state via `TabDirectorDelegate` callbacks so that views
/// observing `TabStore` through `@Environment` see changes immediately.
@Observable @MainActor
final class TabStore {
    /// Checked before a tab closes; returns true when it takes the close over (it asks first and
    /// closes the tab later). Set by EnvironmentState for open PostgreSQL transactions.
    @ObservationIgnored var closeGuard: ((WorkspaceTab) -> Bool)?
    /// Holds back closing a tab with unsaved changes while it asks; true when it held it back.
    @ObservationIgnored var unsavedChangesGuard: ((WorkspaceTab) -> Bool)?
    /// Closing several tabs at once: given the tabs and the close to run, asks once when several
    /// have unsaved changes; true when it took over the close.
    @ObservationIgnored var severalUnsavedGuard: (([WorkspaceTab], @escaping @MainActor () -> Void) -> Bool)?

    // MARK: - State

    var tabDirector = TabDirector()
    weak var delegate: TabStoreDelegate?

    /// Stored properties mirroring `TabDirector` so `@Observable` can track them.
    private(set) var tabs: [WorkspaceTab] = []
    var hasTabs: Bool = false
    private var _activeTabId: UUID? {
        didSet { refreshToolbarContext() }
    }

    /// Which toolbar groups the active tab needs. Stored, and set only when it changes, so the
    /// toolbar's content isn't rebuilt on every tab switch (rebuilding it re-creates the window's
    /// toolbar items, about 60 ms).
    private(set) var activeTabToolbarContext = WorkspaceToolbarContext(kind: nil, databaseType: nil)
    /// The active tab's kind, set with the toolbar context. Toolbar items check it before reading
    /// the active tab, so a switch between tabs they don't serve leaves them alone (each update
    /// rebuilt their overflow menu forms).
    private(set) var activeTabKind: WorkspaceTab.Kind?
    @ObservationIgnored private var toolbarContextTask: Task<Void, Never>?

    /// Alert state for confirming close of tabs with pending changes.
    var showPendingChangesAlert = false
    var pendingCloseTabID: UUID?

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
        let director = tabDirector
        if severalUnsavedGuard?(tabs.filter { $0.id != id }, { director.closeOtherTabs(keeping: id) }) == true { return }
        tabDirector.closeOtherTabs(keeping: id)
    }

    func closeTabsLeft(of id: UUID) {
        let director = tabDirector
        if severalUnsavedGuard?(Array(tabs.prefix(while: { $0.id != id })), { director.closeTabsLeft(of: id) }) == true { return }
        tabDirector.closeTabsLeft(of: id)
    }

    func closeTabsRight(of id: UUID) {
        let director = tabDirector
        if severalUnsavedGuard?(Array(tabs.drop(while: { $0.id != id }).dropFirst()), { director.closeTabsRight(of: id) }) == true { return }
        tabDirector.closeTabsRight(of: id)
    }

    func closeAllTabs() {
        let director = tabDirector
        if severalUnsavedGuard?(tabs, { director.closeAllTabs() }) == true { return }
        tabDirector.closeAllTabs()
    }

    func index(of id: UUID) -> Int? {
        tabs.firstIndex(where: { $0.id == id })
    }

    func confirmCloseTabWithPendingChanges() {
        guard let id = pendingCloseTabID else { return }
        pendingCloseTabID = nil
        tabDirector.removeTab(withID: id)
    }

    func cancelCloseTabWithPendingChanges() {
        pendingCloseTabID = nil
    }

    func clearActiveTab() {
        activeTabId = nil
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
        refreshToolbarContext()
    }

    private func refreshToolbarContext() {
        let tab = activeTab
        let context = WorkspaceToolbarContext(kind: tab?.kind, databaseType: tab?.connection.databaseType)
        guard context != activeTabToolbarContext || tab?.kind != activeTabKind else { return }
        // A frame later: re-creating the toolbar's items takes ~50 ms, and done in the same update
        // it held back the new tab itself. The tab shows first, the toolbar follows.
        toolbarContextTask?.cancel()
        toolbarContextTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            let current = WorkspaceToolbarContext(kind: self.activeTab?.kind, databaseType: self.activeTab?.connection.databaseType)
            if current != self.activeTabToolbarContext { self.activeTabToolbarContext = current }
            if self.activeTab?.kind != self.activeTabKind { self.activeTabKind = self.activeTab?.kind }
        }
    }
}

// MARK: - TabDirectorDelegate

extension TabStore: TabDirectorDelegate {
    func tabDirector(_ manager: TabDirector, didAdd tab: WorkspaceTab) {
        syncTabs()
        delegate?.tabStore(self, didAdd: tab)
    }

    func tabDirector(_ manager: TabDirector, shouldClose tab: WorkspaceTab) -> Bool {
        // A PostgreSQL transaction that would be lost asks first (round 21); the guard closes the
        // tab itself once it is resolved.
        if closeGuard?(tab) == true { return false }
        if unsavedChangesGuard?(tab) == true { return false }
        if case .structure(let editor) = tab.content, editor.hasPendingChanges {
            pendingCloseTabID = tab.id
            showPendingChangesAlert = true
            return false
        }
        return true
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

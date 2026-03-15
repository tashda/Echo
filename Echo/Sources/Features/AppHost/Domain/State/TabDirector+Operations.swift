import Foundation

extension TabDirector {

    // MARK: - Pinning

    func togglePin(for id: UUID) {
        guard let tab = getTab(id: id) else { return }
        if tab.isPinned {
            unpinTab(id: id)
        } else {
            pinTab(id: id)
        }
    }

    func pinTab(id: UUID) {
        guard let currentIndex = index(of: id) else { return }
        let tab = tabs.remove(at: currentIndex)
        let wasActive = activeTabId == tab.id

        guard !tab.isPinned else {
            tabs.insert(tab, at: currentIndex)
            if wasActive { activeTabId = tab.id }
            return
        }

        tab.isPinned = true
        let pinnedCount = tabs.filter { $0.isPinned }.count
        insertTab(tab, at: pinnedCount, activate: wasActive, notifyDelegate: false)
        delegate?.tabDirectorDidReorderTabs(self)
    }

    func unpinTab(id: UUID) {
        guard let currentIndex = index(of: id) else { return }
        let tab = tabs.remove(at: currentIndex)
        let wasActive = activeTabId == tab.id

        guard tab.isPinned else {
            tabs.insert(tab, at: currentIndex)
            if wasActive { activeTabId = tab.id }
            return
        }

        tab.isPinned = false
        let pinnedCount = tabs.filter { $0.isPinned }.count
        insertTab(tab, at: pinnedCount, activate: wasActive, notifyDelegate: false)
        delegate?.tabDirectorDidReorderTabs(self)
    }

    func pinnedCount() -> Int {
        tabs.filter { $0.isPinned }.count
    }

    // MARK: - Closing Helpers

    @discardableResult
    func reopenLastClosedTab(activate shouldActivate: Bool = true) -> WorkspaceTab? {
        guard let snapshot = popClosedTabSnapshot() else { return nil }
        let insertionIndex = min(max(snapshot.index, 0), tabs.count)
        insertTab(snapshot.tab, at: insertionIndex, activate: shouldActivate, notifyDelegate: true)
        return snapshot.tab
    }

    func closeOtherTabs(keeping id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        let idsToRemove = tabs.compactMap { $0.id == id ? nil : $0.id }
        let shouldActivate = activeTabId == id

        for tabID in idsToRemove {
            if !closeTab(id: tabID) {
                break
            }
        }

        if (shouldActivate || activeTabId != id), tabs.contains(where: { $0.id == id }) {
            activeTabId = id
        }
    }

    func closeTabsLeft(of id: UUID) {
        guard let index = index(of: id), index > 0 else { return }
        let idsToRemove = tabs[..<index].map(\.id)
        let shouldActivate = activeTabId == id

        for tabID in idsToRemove.reversed() {
            if !closeTab(id: tabID) {
                break
            }
        }

        if (shouldActivate || activeTabId != id), tabs.contains(where: { $0.id == id }) {
            activeTabId = id
        }
    }

    func closeTabsRight(of id: UUID) {
        guard let index = index(of: id), index < tabs.count - 1 else { return }
        let idsToRemove = tabs[(index + 1)...].map(\.id)
        let shouldActivate = activeTabId == id

        for tabID in idsToRemove {
            if !closeTab(id: tabID) {
                break
            }
        }

        if (shouldActivate || activeTabId != id), tabs.contains(where: { $0.id == id }) {
            activeTabId = id
        }
    }

    func removeTabFromWindowClose(id: UUID) {
        _ = closeTab(id: id)
    }

    func reorderTabs(toMatch orderedIDs: [UUID]) {
        guard !tabs.isEmpty else { return }

        let idSet = Set(orderedIDs)
        var orderedTabs: [WorkspaceTab] = []
        orderedTabs.reserveCapacity(tabs.count)

        for id in orderedIDs {
            if let tab = tabs.first(where: { $0.id == id }) {
                orderedTabs.append(tab)
            }
        }

        orderedTabs.append(contentsOf: tabs.filter { !idSet.contains($0.id) })

        guard orderedTabs.count == tabs.count,
              orderedTabs.map(\.id) != tabs.map(\.id) else { return }

        tabs = orderedTabs
        delegate?.tabDirectorDidReorderTabs(self)
    }
}

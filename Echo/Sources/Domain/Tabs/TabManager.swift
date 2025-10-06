import Foundation
import SwiftUI
import Combine

protocol TabManagerDelegate: AnyObject {
    func tabManager(_ manager: TabManager, didAdd tab: WorkspaceTab)
    func tabManager(_ manager: TabManager, didRemoveTabID tabID: UUID)
    func tabManager(_ manager: TabManager, didSetActiveTabID tabID: UUID?)
    func tabManagerDidReorderTabs(_ manager: TabManager)
}

@MainActor
final class TabManager: ObservableObject {
    weak var delegate: TabManagerDelegate?

    @Published var tabs: [WorkspaceTab] = []
    @Published var activeTabId: UUID? {
        didSet {
            guard activeTabId != oldValue else { return }
            delegate?.tabManager(self, didSetActiveTabID: activeTabId)
        }
    }

    var activeTab: WorkspaceTab? {
        guard let activeID = activeTabId else { return nil }
        return tabs.first { $0.id == activeID }
    }

    // MARK: - Tab Lifecycle

    func addTab(_ tab: WorkspaceTab) {
        insertTab(tab, at: tabs.count)
    }

    func insertTab(_ tab: WorkspaceTab, at index: Int, activate shouldActivate: Bool = true, notifyDelegate: Bool = true) {
        let pinnedCount = tabs.filter { $0.isPinned }.count
        let finalCount = tabs.count

        let insertionIndex: Int
        if tab.isPinned {
            insertionIndex = min(max(index, 0), pinnedCount)
        } else {
            let minIndex = pinnedCount
            insertionIndex = min(max(index, minIndex), finalCount)
        }

        tabs.insert(tab, at: insertionIndex)

        if shouldActivate {
            activeTabId = tab.id
        }

        if notifyDelegate {
            delegate?.tabManager(self, didAdd: tab)
        }
    }

    func removeTab(withID id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let removedTabIsActive = (activeTabId == id)
        let fallbackTabId: UUID? = {
            if index < tabs.endIndex - 1 {
                return tabs[index + 1].id
            }
            return index > 0 ? tabs[index - 1].id : nil
        }()

        tabs.remove(at: index)

        if removedTabIsActive {
            activeTabId = fallbackTabId
        }

        delegate?.tabManager(self, didRemoveTabID: id)
    }

    func closeTab(id: UUID) {
        removeTab(withID: id)
    }

    func setActiveTab(_ id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            activeTabId = id
        }
    }

    func getTab(id: UUID) -> WorkspaceTab? {
        tabs.first { $0.id == id }
    }

    func index(of id: UUID) -> Int? {
        tabs.firstIndex { $0.id == id }
    }

    // MARK: - Reordering

    func moveTab(id: UUID, to proposedIndex: Int) {
        guard let currentIndex = index(of: id) else { return }
        let tab = tabs.remove(at: currentIndex)

        let pinnedCountAfterRemoval = tabs.filter { $0.isPinned }.count
        let finalCountAfterInsertion = tabs.count + 1

        let minIndex: Int
        let maxIndex: Int

        if tab.isPinned {
            minIndex = 0
            maxIndex = max(pinnedCountAfterRemoval, 0)
        } else {
            minIndex = pinnedCountAfterRemoval
            maxIndex = finalCountAfterInsertion - 1
        }

        var destination = min(max(proposedIndex, minIndex), maxIndex)

        if currentIndex < destination {
            destination -= 1
        }

        destination = min(max(destination, minIndex), maxIndex)

        tabs.insert(tab, at: destination)

        if activeTabId == tab.id {
            activeTabId = tab.id
        }

        delegate?.tabManagerDidReorderTabs(self)
    }

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
        delegate?.tabManagerDidReorderTabs(self)
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
        delegate?.tabManagerDidReorderTabs(self)
    }

    func pinnedCount() -> Int {
        tabs.filter { $0.isPinned }.count
    }

    // MARK: - Closing Helpers

    func closeOtherTabs(keeping id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        let idsToRemove = tabs.compactMap { $0.id == id ? nil : $0.id }
        let shouldActivate = activeTabId == id

        idsToRemove.forEach { removeTab(withID: $0) }

        if shouldActivate || activeTabId != id {
            activeTabId = id
        }
    }

    func closeTabsLeft(of id: UUID) {
        guard let index = index(of: id), index > 0 else { return }
        let idsToRemove = tabs[..<index].map(\.id)
        let shouldActivate = activeTabId == id

        idsToRemove.forEach { removeTab(withID: $0) }

        if shouldActivate || activeTabId != id {
            activeTabId = id
        }
    }

    func closeTabsRight(of id: UUID) {
        guard let index = index(of: id), index < tabs.count - 1 else { return }
        let idsToRemove = tabs[(index + 1)...].map(\.id)
        let shouldActivate = activeTabId == id

        idsToRemove.forEach { removeTab(withID: $0) }

        if shouldActivate || activeTabId != id {
            activeTabId = id
        }
    }

    func removeTabFromWindowClose(id: UUID) {
        removeTab(withID: id)
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
        delegate?.tabManagerDidReorderTabs(self)
    }
}

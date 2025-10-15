import Foundation
import SwiftUI
import Combine

protocol TabManagerDelegate: AnyObject {
    func tabManager(_ manager: TabManager, didAdd tab: WorkspaceTab)
    func tabManager(_ manager: TabManager, didRemoveTabID tabID: UUID)
    func tabManager(_ manager: TabManager, didSetActiveTabID tabID: UUID?)
    func tabManagerDidReorderTabs(_ manager: TabManager)
    func tabManager(_ manager: TabManager, shouldClose tab: WorkspaceTab) -> Bool
}

extension TabManagerDelegate {
    func tabManager(_ manager: TabManager, shouldClose tab: WorkspaceTab) -> Bool { true }
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

    private struct ClosedTabSnapshot {
        let tab: WorkspaceTab
        let index: Int
    }

    private var closedTabHistory: [ClosedTabSnapshot] = []
    private let closedTabHistoryLimit = 100

    var canReopenClosedTab: Bool { !closedTabHistory.isEmpty }

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

    @discardableResult
    func closeTab(id: UUID) -> Bool {
        guard let index = index(of: id) else { return false }
        let tab = tabs[index]
        guard delegate?.tabManager(self, shouldClose: tab) ?? true else { return false }
        recordClosedTab(tab, index: index)
        removeTab(withID: id)
        return true
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

    func activateNextTab() {
        guard !tabs.isEmpty else { return }
        if let activeID = activeTabId, let currentIndex = index(of: activeID) {
            let nextIndex = (currentIndex + 1) % tabs.count
            activeTabId = tabs[nextIndex].id
        } else {
            activeTabId = tabs.first?.id
        }
    }

    func activatePreviousTab() {
        guard !tabs.isEmpty else { return }
        if let activeID = activeTabId, let currentIndex = index(of: activeID) {
            let previousIndex = (currentIndex - 1 + tabs.count) % tabs.count
            activeTabId = tabs[previousIndex].id
        } else {
            activeTabId = tabs.last?.id
        }
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

        let destination = min(max(proposedIndex, minIndex), maxIndex)

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

    @discardableResult
    func reopenLastClosedTab(activate shouldActivate: Bool = true) -> WorkspaceTab? {
        guard let snapshot = closedTabHistory.popLast() else { return nil }
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
        delegate?.tabManagerDidReorderTabs(self)
    }

    private func recordClosedTab(_ tab: WorkspaceTab, index: Int) {
        closedTabHistory.removeAll { $0.tab.id == tab.id }
        closedTabHistory.append(.init(tab: tab, index: index))
        if closedTabHistory.count > closedTabHistoryLimit {
            closedTabHistory.removeFirst(closedTabHistory.count - closedTabHistoryLimit)
        }
    }
}

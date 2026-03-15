import Foundation
import SwiftUI
import Combine

protocol TabDirectorDelegate: AnyObject {
    func tabDirector(_ manager: TabDirector, didAdd tab: WorkspaceTab)
    func tabDirector(_ manager: TabDirector, didRemoveTabID tabID: UUID)
    func tabDirector(_ manager: TabDirector, didSetActiveTabID tabID: UUID?)
    func tabDirectorDidReorderTabs(_ manager: TabDirector)
    func tabDirector(_ manager: TabDirector, shouldClose tab: WorkspaceTab) -> Bool
}

extension TabDirectorDelegate {
    func tabDirector(_ manager: TabDirector, shouldClose tab: WorkspaceTab) -> Bool { true }
}

@MainActor
final class TabDirector: ObservableObject {
    weak var delegate: TabDirectorDelegate?

    @Published var tabs: [WorkspaceTab] = []
    @Published var activeTabId: UUID? {
        didSet {
            guard activeTabId != oldValue else { return }
            delegate?.tabDirector(self, didSetActiveTabID: activeTabId)
        }
    }

    internal struct ClosedTabSnapshot {
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
            delegate?.tabDirector(self, didAdd: tab)
        }
    }

    func removeTab(withID id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]

        // Proactively clean up tab resources to stop background tasks/streaming
        tab.query?.cancelExecution()
        tab.activityMonitor?.stopStreaming()

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

        delegate?.tabDirector(self, didRemoveTabID: id)
    }

    @discardableResult
    func closeTab(id: UUID) -> Bool {
        guard let index = index(of: id) else { return false }
        let tab = tabs[index]
        guard delegate?.tabDirector(self, shouldClose: tab) ?? true else { return false }
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

        delegate?.tabDirectorDidReorderTabs(self)
    }

    // MARK: - Internal Helpers

    internal func popClosedTabSnapshot() -> ClosedTabSnapshot? {
        closedTabHistory.popLast()
    }

    private func recordClosedTab(_ tab: WorkspaceTab, index: Int) {
        closedTabHistory.removeAll { $0.tab.id == tab.id }
        closedTabHistory.append(.init(tab: tab, index: index))
        if closedTabHistory.count > closedTabHistoryLimit {
            closedTabHistory.removeFirst(closedTabHistory.count - closedTabHistoryLimit)
        }
    }
}

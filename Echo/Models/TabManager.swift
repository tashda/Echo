import Foundation
import SwiftUI
import Combine

@MainActor
final class TabManager: ObservableObject {
    @Published var tabs: [WorkspaceTab] = []
    @Published var activeTabId: UUID?

    var activeTab: WorkspaceTab? {
        guard let activeID = activeTabId else { return nil }
        return tabs.first { $0.id == activeID }
    }

    func addTab(_ tab: WorkspaceTab) {
        tabs.append(tab)
        activeTabId = tab.id
    }

    func removeTab(withID id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        objectWillChange.send()
        let leftNeighborId = index > 0 ? tabs[index - 1].id : nil
        let removedTabIsActive = (activeTabId == id)
        tabs.remove(at: index)

        if removedTabIsActive {
            activeTabId = leftNeighborId
        }
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
        return tabs.first { $0.id == id }
    }
}

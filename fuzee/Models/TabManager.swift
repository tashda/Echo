import Foundation
import SwiftUI
import Combine

@MainActor
final class TabManager: ObservableObject {
    @Published var tabs: [QueryTab] = []
    @Published var activeTabId: UUID?

    var activeTab: QueryTab? {
        guard let activeID = activeTabId else { return nil }
        return tabs.first { $0.id == activeID }
    }

    func addTab(_ tab: QueryTab) {
        tabs.append(tab)
        activeTabId = tab.id
    }

    func addTab(connection: SavedConnection, session: DatabaseSession, connectionSessionID: UUID, title: String? = nil) {
        let tab = QueryTab(
            connection: connection,
            session: session,
            connectionSessionID: connectionSessionID,
            title: title ?? connection.connectionName
        )
        addTab(tab)
    }

    func removeTab(withID id: UUID) {
        objectWillChange.send()
        tabs.removeAll { $0.id == id }
        if activeTabId == id {
            activeTabId = tabs.first?.id
        }
    }

    func closeTab(id: UUID) {
        objectWillChange.send()
        removeTab(withID: id)
    }

    func setActiveTab(_ id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            activeTabId = id
        }
    }

    func getTab(id: UUID) -> QueryTab? {
        return tabs.first { $0.id == id }
    }
}

import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - TabStoreDelegate

extension AppCoordinator: TabStoreDelegate {
    func tabStore(_ store: TabStore, didAdd tab: WorkspaceTab) {
        if store.activeTabId == tab.id {
            environmentState.sessionCoordinator.setActiveSession(tab.connectionSessionID)
        }
    }

    func tabStore(_ store: TabStore, shouldClose tab: WorkspaceTab) async -> Bool {
        if let psql = tab.psql {
            await psql.close()
            return true
        }

        guard let context = tab.bookmarkContext, let queryState = tab.query else {
            return true
        }

#if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Save bookmark \"\(context.displayName)\"?"
        alert.informativeText = "Do you want to save the current query back to this bookmark before closing the tab?"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            let currentQuery = queryState.sql
            if let connection = connectionStore.connections.first(where: { $0.id == tab.connection.id }),
               let projectID = connection.projectID,
               var project = projectStore.projects.first(where: { $0.id == projectID }) {
                environmentState.bookmarkRepository.updateBookmark(context.bookmarkID, in: &project) { b in
                    b.query = currentQuery
                }
                await projectStore.saveProject(project)
            }
            return true
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
#else
        return true
#endif
    }

    func tabStore(_ store: TabStore, didRemoveTabID tabID: UUID) {
        if let activeTab = store.activeTab {
            environmentState.sessionCoordinator.setActiveSession(activeTab.connectionSessionID)
        } else {
            environmentState.sessionCoordinator.activeSessionID = nil
        }
    }

    func tabStore(_ store: TabStore, didSetActiveTabID tabID: UUID?) {
        guard let tabID, let tab = store.getTab(id: tabID) else {
            environmentState.sessionCoordinator.activeSessionID = nil
#if !os(macOS)
            presentConnectionsIfNeeded()
#endif
            return
        }

        environmentState.sessionCoordinator.setActiveSession(tab.connectionSessionID)
    }

    func tabStoreDidReorderTabs(_ store: TabStore) {
        // Future hook for syncing external UI
    }
}

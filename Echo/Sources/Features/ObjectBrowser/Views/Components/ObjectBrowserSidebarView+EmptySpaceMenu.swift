import AppKit
import SwiftUI

/// The menu for the empty space in the tree, and what a double-click does (round 42.4, 42.6).
extension ObjectBrowserSidebarView {
    func emptySpaceMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("New Connection", systemImage: "network") {
            ManageConnectionsWindowController.shared.present(initialSection: .connections)
        }
        menu.addDivider()
        menu.addActionItem("Refresh All Servers", systemImage: "arrow.clockwise") {
            for session in environmentState.sessionGroup.sessions {
                Task {
                    let handle = AppDirector.shared.activityEngine.begin("Refreshing all databases", connectionSessionID: session.id)
                    await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
                    handle.succeed()
                }
            }
        }
        let showsEmpty = viewModel.showsEmptyFolders
        let toggle = menu.addActionItem("Show Empty Folders") {
            viewModel.showsEmptyFolders.toggle()
        }
        toggle.state = showsEmpty ? .on : .off
        return menu
    }

    /// A table or view opens its data on double-click (the first item in its menu); a job opens the Jobs view on it.
    func doubleClickAction(for node: ObjectBrowserNode) -> (() -> Void)? {
        switch node.row {
        case .object(let session, let databaseName, let object)
            where object.type == .table || object.type == .view || object.type == .materializedView:
            return { openObjectData(object, databaseName: databaseName, session: session) }
        case .item(let row) where row.kind == .agentJob:
            return { environmentState.openJobQueueTab(for: row.session, selectJobID: row.item.id) }
        default:
            return nil
        }
    }

    /// Opens a folder's filter field (Filter Tables, Filter Views…).
    func startFilter(of type: SchemaObjectInfo.ObjectType, databaseName: String, session: ConnectionSession) {
        let folderID = ObjectBrowserSidebarViewModel.objectGroupNodeID(
            connectionID: session.connection.id, databaseName: databaseName, objectType: type)
        viewModel.setExpanded(true, nodeID: folderID)
        if viewModel.folderFilters[folderID] == nil { viewModel.folderFilters[folderID] = "" }
    }
}

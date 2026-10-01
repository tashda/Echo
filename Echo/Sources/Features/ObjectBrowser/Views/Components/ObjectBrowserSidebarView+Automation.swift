import SwiftUI

/// DEBUG only: the Explorer performs automation script steps (switch a section, open a folder,
/// collapse or expand a server, reveal it) through the same code a click runs, so recordings and
/// traces measure exactly what a person sees.
extension ObjectBrowserSidebarView {
    func receivesAutomation<V: View>(_ content: V, builtRoots: [ObjectBrowserNode], roots: [ObjectBrowserNode]) -> some View {
        #if DEBUG
        content.onReceive(NotificationCenter.default.publisher(for: ExplorerAutomationCommand.notification)) { notification in
            guard let command = ExplorerAutomationCommand(notification) else { return }
            performAutomation(command, builtRoots: builtRoots, roots: roots)
        }
        #else
        content
        #endif
    }

    #if DEBUG
    private func performAutomation(_ command: ExplorerAutomationCommand, builtRoots: [ObjectBrowserNode], roots: [ObjectBrowserNode]) {
        guard let session = environmentState.sessionGroup.sessions.first(where: { $0.connection.connectionName == command.server }),
              let (server, _) = serverNode(session.connection.id, in: roots)
        else { return }
        let connectionID = session.connection.id
        switch command.action {
        case "section":
            guard case .dock(_, let layout, _) = server.children.first?.row else { return }
            let itemID: String? = command.target == "More"
                ? ExplorerDock.moreItemID(connectionID)
                : layout.all.first(where: { $0.title == command.target })?.id
            if let itemID { selectDockSection(itemID, connectionID: connectionID, builtRoots: builtRoots) }
        case "folder":
            guard let node = findNode(titled: command.target, in: server.children) else { return }
            handleExpansionChange(of: node, isExpanded: !viewModel.expandedNodeIDs.contains(node.id))
        case "collapse", "expand":
            handleExpansionChange(of: server, isExpanded: command.action == "expand")
        case "reveal":
            reveal(nodeID: server.id)
        default:
            break
        }
    }

    /// The first visible folder or database with this title, depth first.
    private func findNode(titled title: String?, in nodes: [ObjectBrowserNode]) -> ObjectBrowserNode? {
        for node in nodes {
            switch node.row {
            case .folder(let folder) where folder.kind.title == title: return node
            case .database(_, let database, _) where database.name == title: return node
            default: break
            }
            if viewModel.expandedNodeIDs.contains(node.id), let match = findNode(titled: title, in: node.children) { return match }
        }
        return nil
    }
    #endif
}

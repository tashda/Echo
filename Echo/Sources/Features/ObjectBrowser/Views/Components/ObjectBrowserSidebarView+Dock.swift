import SwiftUI

/// Switching a server's dock section (TC1): remembers where the old section was scrolled to,
/// opens the new one (loading its items like expanding a folder would), and returns to where
/// that section was left, or to the server's card.
extension ObjectBrowserSidebarView {
    func selectDockSection(_ itemID: String, connectionID: UUID, builtRoots: [ObjectBrowserNode]) {
        let server = builtRoots.first { if case .server(let session) = $0.row { session.connection.id == connectionID } else { false } }
        guard let server, let items = ExplorerDock.items(for: server.children, connectionID: connectionID) else { return }
        let current = ExplorerDock.selectedID(in: items, saved: viewModel.dockSelection(for: connectionID))
        guard current != itemID else { return }

        if let top = viewModel.topVisibleRow, top.connectionID == connectionID {
            viewModel.setDockScrollAnchor(top.id, connectionID: connectionID, itemID: current)
        }
        withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
            viewModel.setDockSelection(itemID, for: connectionID)
        }
        if let section = ExplorerDock.section(for: itemID, in: builtRoots) {
            handleExpansionChange(of: section, isExpanded: true)
        }
        reveal(nodeID: viewModel.dockScrollAnchor(connectionID: connectionID, itemID: itemID) ?? server.id)
    }
}

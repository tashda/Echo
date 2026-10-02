import AppKit
import SwiftUI

/// The context menu of a recent server in the rail (round 55): connect it, change how it looks,
/// edit it, or take it off the recents.
extension ServerRail {
    func recentMenu(for connection: SavedConnection) -> NSMenu {
        let menu = NSMenu()
        let connectionID = connection.id
        menu.addActionItem("Connect", systemImage: "bolt.fill") {
            connectRecent(connection)
        }
        addAppearanceItem(to: menu, forID: connectionID)
        menu.addDivider()
        menu.addActionItem("Edit Connection", systemImage: "slider.horizontal.3") {
            ManageConnectionsWindowController.shared.present(
                initialSection: .connections,
                selectedConnectionID: connectionID
            )
        }
        menu.addDivider()
        menu.addActionItem("Remove from Recents", systemImage: "minus.circle") {
            hoveredServerID = nil
            withAnimation(motion.standard) {
                environmentState.removeFromRecents(connectionID: connectionID)
            }
        }
        return menu
    }
}

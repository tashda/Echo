import AppKit
import SwiftUI

/// The Object menu: the commands of the row selected in the Explorer (round 42.1, MB0).
struct ObjectMenuCommands: Commands {
    @Bindable var selection: ExplorerSelectionMenu

    var body: some Commands {
        CommandMenu("Object") {
            if let menu = selection.menu {
                ObjectMenuItems(menu: menu)
            } else {
                Button("No Object Selected") {}
                    .disabled(true)
            }
        }
    }
}

/// An `NSMenu`'s items as menu-bar items, submenus included.
private struct ObjectMenuItems: View {
    let menu: NSMenu

    var body: some View {
        ForEach(Array(menu.items.enumerated()), id: \.offset) { _, item in
            if item.isSeparatorItem {
                Divider()
            } else if let submenu = item.submenu {
                Menu(item.title) { ObjectMenuItems(menu: submenu) }
            } else {
                Button(item.state == .on ? "✓ \(item.title)" : item.title) {
                    guard let action = item.action else { return }
                    NSApp.sendAction(action, to: item.target, from: item)
                }
                .disabled(!item.isEnabled)
            }
        }
    }
}

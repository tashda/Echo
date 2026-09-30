import AppKit
import SwiftUI

/// What a right-click in the tree lands on: the row, and how to build its menu.
struct ExplorerTreeContextTarget {
    let nodeID: String
    let menu: () -> NSMenu?
}

/// One AppKit view for the whole tree's context menus. Each row used to carry its own, and with
/// dozens of rows that made every animation frame walk dozens of AppKit views (opaque regions,
/// responders). This one finds the row under the pointer from the tree's layout, so rows are pure
/// SwiftUI. It answers only menu clicks (right-click, Control-click) and only where there is a
/// row with a menu; everything else, the dock's own menus included, passes through.
struct ExplorerTreeContextMenuHost: NSViewRepresentable {
    let target: (CGPoint) -> ExplorerTreeContextTarget?
    /// Called with the row whose menu opened, and with nil when it closes.
    let onMenu: (String?) -> Void

    func makeNSView(context: Context) -> ExplorerTreeContextMenuView {
        let view = ExplorerTreeContextMenuView()
        view.target = target
        view.onMenu = onMenu
        return view
    }

    func updateNSView(_ view: ExplorerTreeContextMenuView, context: Context) {
        view.target = target
        view.onMenu = onMenu
    }
}

final class ExplorerTreeContextMenuView: NSView, NSMenuDelegate {
    var target: ((CGPoint) -> ExplorerTreeContextTarget?)?
    var onMenu: ((String?) -> Void)?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = window?.currentEvent,
              event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
        else { return nil }
        let local = convert(point, from: superview)
        guard bounds.contains(local), target?(local) != nil else { return nil }
        return self
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let local = convert(event.locationInWindow, from: nil)
        guard let target = target?(local), let menu = target.menu() else { return nil }
        menu.delegate = self
        onMenu?(target.nodeID)
        return menu
    }

    func menuDidClose(_ menu: NSMenu) {
        onMenu?(nil)
    }
}

import SwiftUI
import AppKit

// MARK: - Environment key for context menu active state

struct SidebarContextMenuActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var sidebarContextMenuActive: Bool {
        get { self[SidebarContextMenuActiveKey.self] }
        set { self[SidebarContextMenuActiveKey.self] = newValue }
    }
}

// MARK: - Modifier

/// A ViewModifier that provides context menus via AppKit's NSMenu instead of
/// SwiftUI's `.contextMenu`. The menu is only constructed when the user right-clicks,
/// avoiding SwiftUI's eager evaluation of `.contextMenu` closures during body rendering.
/// Sets `sidebarContextMenuActive` in the environment while the menu is open so that
/// child views (e.g. SidebarRow) can draw the highlight only over their content area.
struct LazyContextMenuModifier: ViewModifier {
    let menuBuilder: () -> NSMenu
    @State private var isMenuVisible = false

    func body(content: Content) -> some View {
        content
            .environment(\.sidebarContextMenuActive, isMenuVisible)
            .overlay {
                LazyContextMenuRepresentable(
                    menuBuilder: menuBuilder,
                    onMenuOpen: { isMenuVisible = true },
                    onMenuClose: { isMenuVisible = false }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }
}

private struct LazyContextMenuRepresentable: NSViewRepresentable {
    let menuBuilder: () -> NSMenu
    let onMenuOpen: () -> Void
    let onMenuClose: () -> Void

    func makeNSView(context: Context) -> LazyContextMenuNSView {
        let view = LazyContextMenuNSView()
        view.menuBuilder = menuBuilder
        view.onMenuOpen = onMenuOpen
        view.onMenuClose = onMenuClose
        return view
    }

    func updateNSView(_ nsView: LazyContextMenuNSView, context: Context) {
        nsView.menuBuilder = menuBuilder
        nsView.onMenuOpen = onMenuOpen
        nsView.onMenuClose = onMenuClose
    }
}

final class LazyContextMenuNSView: NSView, @unchecked Sendable {
    nonisolated(unsafe) var menuBuilder: (() -> NSMenu)?
    nonisolated(unsafe) var onMenuOpen: (() -> Void)?
    nonisolated(unsafe) var onMenuClose: (() -> Void)?

    nonisolated override func menu(for event: NSEvent) -> NSMenu? {
        guard let menu = menuBuilder?() else { return nil }
        menu.delegate = self
        onMenuOpen?()
        return menu
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = window?.currentEvent, event.type == .rightMouseDown else {
            return nil
        }
        return frame.contains(point) ? self : nil
    }
}

extension LazyContextMenuNSView: NSMenuDelegate {
    nonisolated func menuDidClose(_ menu: NSMenu) {
        onMenuClose?()
    }
}

// MARK: - View Extension

extension View {
    func lazyContextMenu(_ menuBuilder: @escaping () -> NSMenu) -> some View {
        modifier(LazyContextMenuModifier(menuBuilder: menuBuilder))
    }
}

// MARK: - NSMenu Convenience Builders

extension NSMenu {
    @discardableResult
    func addActionItem(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, closure: action)
        if let systemImage {
            item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        }
        addItem(item)
        return item
    }

    func addDivider() {
        addItem(.separator())
    }

    @discardableResult
    func addSubmenu(_ title: String, systemImage: String? = nil, builder: (NSMenu) -> Void) -> NSMenuItem {
        let submenu = NSMenu(title: title)
        builder(submenu)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        if let systemImage {
            item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        }
        item.submenu = submenu
        addItem(item)
        return item
    }
}

// MARK: - Closure-based NSMenuItem

final class ClosureMenuItem: NSMenuItem {
    private let closure: () -> Void

    init(title: String, closure: @escaping () -> Void) {
        self.closure = closure
        super.init(title: title, action: #selector(performAction), keyEquivalent: "")
        self.target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }

    @objc private func performAction() {
        closure()
    }
}

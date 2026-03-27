import SwiftUI
import AppKit

/// A ViewModifier that provides context menus via AppKit's NSMenu instead of
/// SwiftUI's `.contextMenu`. The menu is only constructed when the user right-clicks,
/// avoiding SwiftUI's eager evaluation of `.contextMenu` closures during body rendering.
struct LazyContextMenuModifier: ViewModifier {
    let menuBuilder: () -> NSMenu

    func body(content: Content) -> some View {
        content.overlay {
            LazyContextMenuRepresentable(menuBuilder: menuBuilder)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct LazyContextMenuRepresentable: NSViewRepresentable {
    let menuBuilder: () -> NSMenu

    func makeNSView(context: Context) -> LazyContextMenuNSView {
        let view = LazyContextMenuNSView()
        view.menuBuilder = menuBuilder
        return view
    }

    func updateNSView(_ nsView: LazyContextMenuNSView, context: Context) {
        nsView.menuBuilder = menuBuilder
    }
}

final class LazyContextMenuNSView: NSView, @unchecked Sendable {
    // Safe: this view and its menuBuilder are only accessed on the main thread.
    nonisolated(unsafe) var menuBuilder: (() -> NSMenu)?

    nonisolated override func menu(for event: NSEvent) -> NSMenu? {
        // menu(for:) is always called on the main thread by AppKit.
        menuBuilder?()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only claim the hit for right-clicks (context menu).
        // For left-clicks, return nil so SwiftUI buttons underneath receive the tap.
        guard let event = window?.currentEvent, event.type == .rightMouseDown else {
            return nil
        }
        return frame.contains(point) ? self : nil
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

import SwiftUI
#if os(macOS)
import AppKit
import Combine

final class MenuActionHandler: NSObject, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private var handlers: [NSMenuItem: () -> Void] = [:]

    func clear() {
        handlers.removeAll()
    }

    func register(_ menuItem: NSMenuItem, role: ButtonRole? = nil, action: @escaping () -> Void) {
        handlers[menuItem] = action
        menuItem.target = self
        menuItem.action = #selector(performAction(_:))

        if role == .destructive {
            menuItem.attributedTitle = NSAttributedString(
                string: menuItem.title,
                attributes: [.foregroundColor: NSColor.systemRed]
            )
        }
    }

    func symbolImage(named systemName: String) -> NSImage? {
        guard !systemName.isEmpty else { return nil }
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    @objc
    func performAction(_ sender: NSMenuItem) {
        handlers[sender]?()
    }
}
#endif

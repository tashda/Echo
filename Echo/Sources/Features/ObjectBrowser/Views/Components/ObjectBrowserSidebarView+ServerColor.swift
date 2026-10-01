import AppKit
import SwiftUI

/// Round 30.1, SC1: the server header's right-click menu sets the server's colour, with the same
/// swatches as the connection sheet. It is the colour the header, the rail, the server's tabs and
/// the footer's server pill show.
extension ObjectBrowserSidebarView {
    func addServerColorMenu(to menu: NSMenu, session: ConnectionSession) {
        let store = environmentState.connectionStore
        let connectionID = session.connection.id
        let current = store.connections.first { $0.id == connectionID }?.colorHex ?? session.connection.colorHex
        menu.addSubmenu("Color", systemImage: "paintpalette") { submenu in
            for hex in ConnectionEditorView.colorPalette {
                let item = submenu.addActionItem(Self.serverColorName(hex)) {
                    Task { await setServerColor(hex, connectionID: connectionID) }
                }
                item.image = Self.serverColorSwatch(hex)
                item.state = current.caseInsensitiveCompare(hex) == .orderedSame ? .on : .off
            }
        }
    }

    private func setServerColor(_ hex: String, connectionID: UUID) async {
        let store = environmentState.connectionStore
        guard var connection = store.connections.first(where: { $0.id == connectionID }) else { return }
        connection.colorHex = hex
        do {
            try await store.updateConnection(connection)
        } catch {
            environmentState.notificationEngine?.post(category: .generalError, message: "The server's color couldn't be saved: \(error.localizedDescription)")
        }
    }

    /// The connection sheet's swatches, by name.
    static func serverColorName(_ hex: String) -> String {
        switch hex.uppercased() {
        case "5A9CDE": "Blue"
        case "6EAE72": "Green"
        case "E8943A": "Orange"
        case "9B72CF": "Purple"
        case "D4687A": "Rose"
        default: hex
        }
    }

    /// A round swatch for the menu item.
    static func serverColorSwatch(_ hex: String) -> NSImage? {
        guard let color = Color(hex: hex) else { return nil }
        let fill = NSColor(color)
        let side = SpacingTokens.sm
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            fill.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: SpacingTokens.micro, dy: SpacingTokens.micro)).fill()
            return true
        }
    }
}

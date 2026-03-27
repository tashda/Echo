import SwiftUI
import AppKit

/// A button that shows a server/database scope picker as a native NSMenu.
/// Uses AppKit directly because SwiftUI `Menu` on macOS cannot reliably
/// render a plain icon label without adding a chevron or collapsing to zero width.
struct ScopeMenuButton: View {
    let isScopeActive: Bool
    let scope: SearchScope
    let servers: [(id: UUID, name: String)]
    let databases: [String]
    let scopedSessionID: UUID?
    let scopedDatabaseName: String?
    let onScopeChange: (SearchScope) -> Void

    var body: some View {
        Button {
            showMenu()
        } label: {
            Image(systemName: "server.rack")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(isScopeActive ? ColorTokens.accent : ColorTokens.Text.secondary)
        }
        .buttonStyle(.plain)
    }

    private func showMenu() {
        let menu = NSMenu()

        // "All Servers" item
        let allServersItem = NSMenuItem(title: "All Servers", action: nil, keyEquivalent: "")
        allServersItem.state = scope == .allServers ? .on : .off
        allServersItem.target = ScopeMenuTarget.shared
        allServersItem.representedObject = ScopeMenuAction { onScopeChange(.allServers) }
        allServersItem.action = #selector(ScopeMenuTarget.performAction(_:))
        menu.addItem(allServersItem)

        menu.addItem(.separator())

        // Server items
        for server in servers {
            let item = NSMenuItem(title: server.name, action: nil, keyEquivalent: "")
            item.state = scopedSessionID == server.id ? .on : .off
            item.target = ScopeMenuTarget.shared
            item.representedObject = ScopeMenuAction { onScopeChange(.server(connectionSessionID: server.id)) }
            item.action = #selector(ScopeMenuTarget.performAction(_:))
            menu.addItem(item)
        }

        // Database section — only when a server is selected
        if let sessionID = scopedSessionID, !databases.isEmpty {
            menu.addItem(.separator())

            let allDbItem = NSMenuItem(title: "All Databases", action: nil, keyEquivalent: "")
            allDbItem.state = scopedDatabaseName == nil ? .on : .off
            allDbItem.target = ScopeMenuTarget.shared
            allDbItem.representedObject = ScopeMenuAction { onScopeChange(.server(connectionSessionID: sessionID)) }
            allDbItem.action = #selector(ScopeMenuTarget.performAction(_:))
            menu.addItem(allDbItem)

            for dbName in databases {
                let item = NSMenuItem(title: dbName, action: nil, keyEquivalent: "")
                item.state = scopedDatabaseName == dbName ? .on : .off
                item.target = ScopeMenuTarget.shared
                item.representedObject = ScopeMenuAction(sessionID: sessionID, dbName: dbName) {
                    onScopeChange(.database(connectionSessionID: sessionID, databaseName: dbName))
                }
                item.action = #selector(ScopeMenuTarget.performAction(_:))
                menu.addItem(item)
            }
        }

        // Show the menu below the button
        guard let event = NSApp.currentEvent else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: event.window?.contentView ?? NSView())
    }
}

// MARK: - AppKit Menu Target

/// Wraps a closure so NSMenuItem can invoke it via target-action.
private final class ScopeMenuAction: NSObject {
    let handler: () -> Void
    var sessionID: UUID?
    var dbName: String?

    init(sessionID: UUID? = nil, dbName: String? = nil, handler: @escaping () -> Void) {
        self.sessionID = sessionID
        self.dbName = dbName
        self.handler = handler
    }
}

/// Singleton target for NSMenuItem actions — prevents premature deallocation.
private final class ScopeMenuTarget: NSObject, @unchecked Sendable {
    nonisolated static let shared = ScopeMenuTarget()

    @objc func performAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? ScopeMenuAction else { return }
        action.handler()
    }
}

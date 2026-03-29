import SwiftUI

#if os(macOS)
import AppKit

// MARK: - Databases Menu Button

struct DatabasesMenuButton: NSViewRepresentable {
    let connectionStore: ConnectionStore
    let environmentState: EnvironmentState
    let title: String
    let isEnabled: Bool

    func makeCoordinator() -> DatabasesMenuDelegate {
        DatabasesMenuDelegate(connectionStore: connectionStore, environmentState: environmentState)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: true)
        popup.isBordered = true
        popup.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        popup.addItem(withTitle: title)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        popup.item(at: 0)?.image = NSImage(systemSymbolName: "cylinder.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        popup.menu?.delegate = context.coordinator
        popup.isEnabled = isEnabled
        return popup
    }

    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        context.coordinator.connectionStore = connectionStore
        context.coordinator.environmentState = environmentState
        popup.item(at: 0)?.title = title
        popup.isEnabled = isEnabled
        popup.alphaValue = isEnabled ? 1.0 : 0.5
        popup.sizeToFit()
    }
}

@MainActor
final class DatabasesMenuDelegate: NSObject, NSMenuDelegate {
    var connectionStore: ConnectionStore
    var environmentState: EnvironmentState

    init(connectionStore: ConnectionStore, environmentState: EnvironmentState) {
        self.connectionStore = connectionStore
        self.environmentState = environmentState
        super.init()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        while menu.numberOfItems > 1 {
            menu.removeItem(at: menu.numberOfItems - 1)
        }

        guard let connectionID = connectionStore.selectedConnectionID,
              let session = environmentState.sessionGroup.sessionForConnection(connectionID),
              let structure = session.databaseStructure else {
            let empty = NSMenuItem(title: "No databases available", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        let selectedDB = session.sidebarFocusedDatabase

        for db in structure.databases {
            let item = NSMenuItem(title: db.name, action: #selector(selectDatabase(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = db.name
            item.state = (db.name == selectedDB) ? .on : .off
            item.image = NSImage(systemSymbolName: "cylinder", accessibilityDescription: nil)
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh List", action: #selector(refreshDatabases(_:)), keyEquivalent: "")
        refresh.target = self
        refresh.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        menu.addItem(refresh)
    }

    @objc private func selectDatabase(_ sender: NSMenuItem) {
        guard let dbName = sender.representedObject as? String,
              let connectionID = connectionStore.selectedConnectionID,
              let session = environmentState.sessionGroup.sessionForConnection(connectionID) else { return }
        Task { await environmentState.loadSchemaForDatabase(dbName, connectionSession: session) }
    }

    @objc private func refreshDatabases(_ sender: NSMenuItem) {
        guard let connectionID = connectionStore.selectedConnectionID else { return }
        Task { await environmentState.refreshDatabaseStructure(for: connectionID, scope: .full) }
    }
}

#endif

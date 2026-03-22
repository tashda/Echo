import AppKit

#if os(macOS)

@MainActor
enum ConnectionsMenuBuilder {

    static func buildMenu(connectionStore: ConnectionStore, environmentState: EnvironmentState) -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = 260

        let projectID = AppDirector.shared.projectStore.selectedProject?.id

        // MARK: - Recent
        let recentRecords = Array(environmentState.recentConnections.prefix(3))
        let recentConnections = recentRecords.compactMap { record in
            connectionStore.connections.first { $0.id == record.id }
        }

        if !recentConnections.isEmpty {
            menu.addItem(sectionHeader("Recent"))
            for conn in recentConnections {
                menu.addItem(connectionItem(conn, connectionStore: connectionStore, environmentState: environmentState))
            }
            menu.addItem(.separator())
        }

        // MARK: - Folders
        let folders = connectionStore.folders
            .filter { $0.kind == .connections && $0.parentFolderID == nil && $0.projectID == projectID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        for folder in folders {
            let conns = connectionStore.connections
                .filter { $0.folderID == folder.id && $0.projectID == projectID }
                .sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }
            guard !conns.isEmpty else { continue }

            menu.addItem(sectionHeader(folder.name))
            for conn in conns {
                menu.addItem(connectionItem(conn, connectionStore: connectionStore, environmentState: environmentState))
            }
        }

        // MARK: - Unfiled
        let unfiled = connectionStore.connections
            .filter { $0.folderID == nil && $0.projectID == projectID }
            .sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }

        if !unfiled.isEmpty {
            if !folders.isEmpty {
                menu.addItem(sectionHeader("Other"))
            }
            for conn in unfiled {
                menu.addItem(connectionItem(conn, connectionStore: connectionStore, environmentState: environmentState))
            }
        }

        // MARK: - Actions
        menu.addItem(.separator())

        let manageItem = NSMenuItem(title: "Manage Connections", action: #selector(ConnectionsMenuActions.manageConnections(_:)), keyEquivalent: "")
        manageItem.target = ConnectionsMenuActions.shared
        menu.addItem(manageItem)

        let quickItem = NSMenuItem(title: "Quick Connect", action: #selector(ConnectionsMenuActions.quickConnect(_:)), keyEquivalent: "")
        quickItem.target = ConnectionsMenuActions.shared
        menu.addItem(quickItem)

        return menu
    }

    // MARK: - Helpers

    private static func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.isEnabled = false

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        item.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        return item
    }

    private static func connectionItem(
        _ connection: SavedConnection,
        connectionStore: ConnectionStore,
        environmentState: EnvironmentState
    ) -> NSMenuItem {
        let isSelected = connection.id == connectionStore.selectedConnectionID
        let name = displayName(for: connection)

        let item = NSMenuItem(title: name, action: #selector(ConnectionsMenuActions.selectConnection(_:)), keyEquivalent: "")
        item.target = ConnectionsMenuActions.shared
        item.representedObject = ConnectionMenuContext(connection: connection, environmentState: environmentState)

        if isSelected {
            item.state = .on
        }

        if let image = NSImage(named: connection.databaseType.iconName) {
            let sized = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                image.draw(in: rect)
                return true
            }
            item.image = sized
        } else {
            item.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
        }

        return item
    }

    private static func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }
}

// MARK: - Menu Context

final class ConnectionMenuContext: @unchecked Sendable {
    let connection: SavedConnection
    let environmentState: EnvironmentState

    init(connection: SavedConnection, environmentState: EnvironmentState) {
        self.connection = connection
        self.environmentState = environmentState
    }
}

// MARK: - Menu Actions

@MainActor
final class ConnectionsMenuActions: NSObject {
    static let shared = ConnectionsMenuActions()

    @objc func selectConnection(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? ConnectionMenuContext else { return }
        context.environmentState.connect(to: context.connection)
    }

    @objc func manageConnections(_ sender: NSMenuItem) {
        ManageConnectionsWindowController.shared.present()
    }

    @objc func quickConnect(_ sender: NSMenuItem) {
        AppDirector.shared.appState.showSheet(.quickConnect)
    }
}

#endif

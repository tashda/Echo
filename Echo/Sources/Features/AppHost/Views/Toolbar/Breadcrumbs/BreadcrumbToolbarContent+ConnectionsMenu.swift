import SwiftUI

#if os(macOS)
import AppKit

// MARK: - Breadcrumb Connections Menu Button

struct BreadcrumbConnectionsMenuButton: NSViewRepresentable {
    let connectionStore: ConnectionStore
    let projectStore: ProjectStore
    let environmentState: EnvironmentState
    let title: String

    func makeCoordinator() -> ConnectionsMenuDelegate {
        ConnectionsMenuDelegate(connectionStore: connectionStore, projectStore: projectStore, environmentState: environmentState)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: true)
        popup.isBordered = true
        popup.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        popup.addItem(withTitle: title)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        popup.item(at: 0)?.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        popup.menu?.delegate = context.coordinator
        return popup
    }

    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        context.coordinator.connectionStore = connectionStore
        context.coordinator.projectStore = projectStore
        context.coordinator.environmentState = environmentState
        popup.item(at: 0)?.title = title
        popup.sizeToFit()
    }
}

@MainActor
final class ConnectionsMenuDelegate: NSObject, NSMenuDelegate {
    var connectionStore: ConnectionStore
    var projectStore: ProjectStore
    var environmentState: EnvironmentState

    init(connectionStore: ConnectionStore, projectStore: ProjectStore, environmentState: EnvironmentState) {
        self.connectionStore = connectionStore
        self.projectStore = projectStore
        self.environmentState = environmentState
        super.init()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        while menu.numberOfItems > 1 {
            menu.removeItem(at: menu.numberOfItems - 1)
        }

        let projectID = projectStore.selectedProject?.id
        let sessions = environmentState.sessionGroup.activeSessions
        let connectedIDs = Set(sessions.map { $0.connection.id })

        // Connected sessions first
        if !sessions.isEmpty {
            menu.addItem(NSMenuItem.sectionHeader(title: "Connected"))
            for session in sessions {
                let conn = session.connection
                let isActive = conn.id == connectionStore.selectedConnectionID
                let title = displayName(conn)
                let dbSuffix = session.sidebarFocusedDatabase.map { " — \($0)" } ?? ""
                let item = NSMenuItem(title: title + dbSuffix, action: #selector(switchToSession(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = session
                item.state = isActive ? .on : .off
                if let image = conn.databaseType.menuIconImage() {
                    item.image = image
                } else {
                    item.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)
                }
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        // Saved connections (not currently connected)
        let savedConnections = connectionStore.connections
            .filter { $0.projectID == projectID && !connectedIDs.contains($0.id) }
            .sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }

        if !savedConnections.isEmpty {
            if !sessions.isEmpty {
                menu.addItem(NSMenuItem.sectionHeader(title: "Saved"))
            }
            for conn in savedConnections {
                menu.addItem(connectionItem(conn))
            }
            menu.addItem(.separator())
        }

        let manage = NSMenuItem(title: "Manage Connections", action: #selector(manageConnections(_:)), keyEquivalent: "")
        manage.target = self
        manage.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(manage)

        let quick = NSMenuItem(title: "Quick Connect", action: #selector(quickConnect(_:)), keyEquivalent: "")
        quick.target = self
        quick.image = NSImage(systemSymbolName: "bolt", accessibilityDescription: nil)
        menu.addItem(quick)
    }

    @objc private func quickConnect(_ sender: NSMenuItem) {
        AppDirector.shared.appState.showSheet(.quickConnect)
    }

    @objc private func switchToSession(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? ConnectionSession else { return }
        connectionStore.selectedConnectionID = session.connection.id
        environmentState.sessionGroup.setActiveSession(session.id)
    }

    private func connectionItem(_ conn: SavedConnection) -> NSMenuItem {
        let item = NSMenuItem(title: displayName(conn), action: #selector(connectTo(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = conn
        item.state = .off
        if let image = conn.databaseType.menuIconImage() {
            item.image = image
        } else {
            item.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)
        }
        return item
    }

    private func displayName(_ conn: SavedConnection) -> String {
        let trimmed = conn.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? conn.host : trimmed
    }

    @objc private func connectTo(_ sender: NSMenuItem) {
        guard let connection = sender.representedObject as? SavedConnection else { return }
        environmentState.connect(to: connection)
    }

    @objc private func manageConnections(_ sender: NSMenuItem) {
        ManageConnectionsWindowController.shared.present()
    }
}

#endif

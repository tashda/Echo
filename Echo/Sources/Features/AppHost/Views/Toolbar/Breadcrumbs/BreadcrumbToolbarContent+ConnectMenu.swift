import SwiftUI

#if os(macOS)
import AppKit

// MARK: - Connect Toolbar Menu Button (bolt icon, same menu as Connections)

struct ConnectToolbarMenuButton: NSViewRepresentable {
    let connectionStore: ConnectionStore
    let projectStore: ProjectStore
    let environmentState: EnvironmentState

    func makeCoordinator() -> ConnectToolbarMenuDelegate {
        ConnectToolbarMenuDelegate(connectionStore: connectionStore, projectStore: projectStore, environmentState: environmentState)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .toolbar
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.title = ""
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Connect")?
            .withSymbolConfiguration(config)
        button.imagePosition = .imageOnly
        button.target = context.coordinator
        button.action = #selector(ConnectToolbarMenuDelegate.showMenu(_:))
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.connectionStore = connectionStore
        context.coordinator.projectStore = projectStore
        context.coordinator.environmentState = environmentState
    }
}

@MainActor
final class ConnectToolbarMenuDelegate: NSObject {
    var connectionStore: ConnectionStore
    var projectStore: ProjectStore
    var environmentState: EnvironmentState

    init(connectionStore: ConnectionStore, projectStore: ProjectStore, environmentState: EnvironmentState) {
        self.connectionStore = connectionStore
        self.projectStore = projectStore
        self.environmentState = environmentState
        super.init()
    }

    @objc func showMenu(_ sender: NSButton) {
        let menu = NSMenu()
        let projectID = projectStore.selectedProject?.id
        let sessions = environmentState.sessionGroup.activeSessions
        let connectedIDs = Set(sessions.map { $0.connection.id })

        if !sessions.isEmpty {
            menu.addItem(NSMenuItem.sectionHeader(title: "Connected"))
            for session in sessions {
                let conn = session.connection
                let isActive = conn.id == connectionStore.selectedConnectionID
                let title = displayName(conn)
                let dbSuffix = session.selectedDatabaseName.map { " — \($0)" } ?? ""
                let item = NSMenuItem(title: title + dbSuffix, action: #selector(switchToSession(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = session
                item.state = isActive ? .on : .off
                if let image = NSImage(named: conn.databaseType.iconName) {
                    image.size = NSSize(width: 16, height: 16)
                    item.image = image
                } else {
                    item.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)
                }
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let savedConnections = connectionStore.connections
            .filter { $0.projectID == projectID && !connectedIDs.contains($0.id) }
            .sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }

        if !savedConnections.isEmpty {
            if !sessions.isEmpty {
                menu.addItem(NSMenuItem.sectionHeader(title: "Saved"))
            }
            for conn in savedConnections {
                let item = NSMenuItem(title: displayName(conn), action: #selector(connectTo(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = conn
                item.state = .off
                if let image = NSImage(named: conn.databaseType.iconName) {
                    image.size = NSSize(width: 16, height: 16)
                    item.image = image
                } else {
                    item.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)
                }
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let manage = NSMenuItem(title: "Manage Connections\u{2026}", action: #selector(manageConnections(_:)), keyEquivalent: "")
        manage.target = self
        manage.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(manage)

        let quick = NSMenuItem(title: "Quick Connect\u{2026}", action: #selector(quickConnect(_:)), keyEquivalent: "")
        quick.target = self
        quick.image = NSImage(systemSymbolName: "bolt", accessibilityDescription: nil)
        menu.addItem(quick)

        let point = NSPoint(x: 0, y: sender.bounds.maxY + 4)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func quickConnect(_ sender: NSMenuItem) {
        AppDirector.shared.appState.showSheet(.quickConnect)
    }

    @objc private func switchToSession(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? ConnectionSession else { return }
        connectionStore.selectedConnectionID = session.connection.id
        environmentState.sessionGroup.setActiveSession(session.id)
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

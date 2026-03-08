import SwiftUI

#if os(macOS)
import AppKit

/// Breadcrumb toolbar content using native NSPopUpButton menus.
///
/// Menus flow from the toolbar with native Liquid Glass on macOS 26.
/// Uses NSViewRepresentable wrappers so SwiftUI manages the toolbar
/// while the menus are pure AppKit.
struct BreadcrumbToolbarContent: View {
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var environmentState: EnvironmentState

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            ConnectionsMenuButton(
                connectionStore: connectionStore,
                projectStore: projectStore,
                environmentState: environmentState,
                title: connectionsTitle
            )
            DatabasesMenuButton(
                connectionStore: connectionStore,
                environmentState: environmentState,
                title: databaseTitle,
                isEnabled: connectionStore.selectedConnectionID != nil
            )
            Spacer(minLength: SpacingTokens.sm)
            statusLabel
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Status

    private var statusLabel: some View {
        Group {
            if let text = statusText, !text.isEmpty {
                Text(text)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    // MARK: - Derived State

    private var connectionsTitle: String {
        connectionStore.selectedConnection.map {
            $0.connectionName.isEmpty ? $0.host : $0.connectionName
        } ?? "Connections"
    }

    private var databaseTitle: String {
        (connectionStore.selectedConnectionID.flatMap {
            environmentState.sessionCoordinator.sessionForConnection($0)
        }?.selectedDatabaseName).map {
            $0.isEmpty ? "Databases" : $0
        } ?? "Databases"
    }

    private var statusText: String? {
        guard let id = connectionStore.selectedConnectionID else { return "No Connection" }
        switch environmentState.connectionStates[id] {
        case .testing: return "Testing\u{2026}"
        case .connecting: return "Connecting\u{2026}"
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .error: return "Error"
        default:
            return environmentState.sessionCoordinator.sessionForConnection(id) != nil
                ? "Connected" : "Disconnected"
        }
    }
}

// MARK: - Connections Menu Button

struct ConnectionsMenuButton: NSViewRepresentable {
    let connectionStore: ConnectionStore
    let projectStore: ProjectStore
    let environmentState: EnvironmentState
    let title: String

    func makeCoordinator() -> ConnectionsMenuCoordinator {
        ConnectionsMenuCoordinator(connectionStore: connectionStore, projectStore: projectStore, environmentState: environmentState)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: true)
        popup.isBordered = false
        popup.font = .systemFont(ofSize: 12, weight: .regular)
        (popup.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtBottom
        popup.addItem(withTitle: title)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        popup.item(at: 0)?.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        popup.menu?.delegate = context.coordinator
        popup.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return popup
    }

    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        context.coordinator.connectionStore = connectionStore
        context.coordinator.projectStore = projectStore
        context.coordinator.environmentState = environmentState
        popup.item(at: 0)?.title = title
    }
}

@MainActor
final class ConnectionsMenuCoordinator: NSObject, NSMenuDelegate {
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

        // Folder sections
        let folders = connectionStore.folders
            .filter { $0.kind == .connections && $0.parentFolderID == nil && $0.projectID == projectID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        for folder in folders {
            let conns = connectionStore.connections
                .filter { $0.folderID == folder.id && $0.projectID == projectID }
                .sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
            guard !conns.isEmpty else { continue }
            menu.addItem(NSMenuItem.sectionHeader(title: folder.name))
            for conn in conns { menu.addItem(connectionItem(conn)) }
        }

        // Unfiled connections
        let unfiled = connectionStore.connections
            .filter { $0.folderID == nil && $0.projectID == projectID }
            .sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
        if !unfiled.isEmpty {
            if !folders.isEmpty { menu.addItem(NSMenuItem.sectionHeader(title: "Other")) }
            for conn in unfiled { menu.addItem(connectionItem(conn)) }
        }

        menu.addItem(.separator())

        let manage = NSMenuItem(title: "Manage Connections\u{2026}", action: #selector(manageConnections(_:)), keyEquivalent: "")
        manage.target = self
        manage.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(manage)

        let quick = NSMenuItem(title: "Quick Connect\u{2026}", action: #selector(manageConnections(_:)), keyEquivalent: "")
        quick.target = self
        quick.image = NSImage(systemSymbolName: "bolt", accessibilityDescription: nil)
        menu.addItem(quick)
    }

    private func connectionItem(_ conn: SavedConnection) -> NSMenuItem {
        let isSelected = conn.id == connectionStore.selectedConnectionID
        let item = NSMenuItem(title: displayName(conn), action: #selector(connectTo(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = conn
        item.state = isSelected ? .on : .off
        if let image = NSImage(named: conn.databaseType.iconName) {
            image.size = NSSize(width: 16, height: 16)
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
        Task { await environmentState.connect(to: connection) }
    }

    @objc private func manageConnections(_ sender: NSMenuItem) {
        ManageConnectionsWindowController.shared.present()
    }
}

// MARK: - Databases Menu Button

struct DatabasesMenuButton: NSViewRepresentable {
    let connectionStore: ConnectionStore
    let environmentState: EnvironmentState
    let title: String
    let isEnabled: Bool

    func makeCoordinator() -> DatabasesMenuCoordinator {
        DatabasesMenuCoordinator(connectionStore: connectionStore, environmentState: environmentState)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: true)
        popup.isBordered = false
        popup.font = .systemFont(ofSize: 12, weight: .regular)
        (popup.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtBottom
        popup.addItem(withTitle: title)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        popup.item(at: 0)?.image = NSImage(systemSymbolName: "cylinder.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        popup.menu?.delegate = context.coordinator
        popup.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        popup.isEnabled = isEnabled
        return popup
    }

    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        context.coordinator.connectionStore = connectionStore
        context.coordinator.environmentState = environmentState
        popup.item(at: 0)?.title = title
        popup.isEnabled = isEnabled
        popup.alphaValue = isEnabled ? 1.0 : 0.5
    }
}

@MainActor
final class DatabasesMenuCoordinator: NSObject, NSMenuDelegate {
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
              let session = environmentState.sessionCoordinator.sessionForConnection(connectionID),
              let structure = session.databaseStructure else {
            let empty = NSMenuItem(title: "No databases available", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        let selectedDB = session.selectedDatabaseName

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
              let session = environmentState.sessionCoordinator.sessionForConnection(connectionID) else { return }
        Task { await environmentState.loadSchemaForDatabase(dbName, connectionSession: session) }
    }

    @objc private func refreshDatabases(_ sender: NSMenuItem) {
        guard let connectionID = connectionStore.selectedConnectionID else { return }
        Task { await environmentState.refreshDatabaseStructure(for: connectionID, scope: .full) }
    }
}

#endif

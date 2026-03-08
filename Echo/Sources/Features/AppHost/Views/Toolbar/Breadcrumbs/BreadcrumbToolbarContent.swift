import SwiftUI

#if os(macOS)
import AppKit

/// Native NSPopUpButton toolbar menus for Project, Connections, and Databases.
///
/// Menus flow from the toolbar with native Liquid Glass on macOS 26.
/// Uses NSViewRepresentable wrappers so SwiftUI manages the toolbar
/// while the menus are pure AppKit.

// MARK: - Project Menu Button

struct ProjectMenuButton: NSViewRepresentable {
    let projectStore: ProjectStore
    let navigationStore: NavigationStore

    func makeCoordinator() -> ProjectMenuCoordinator {
        ProjectMenuCoordinator(projectStore: projectStore, navigationStore: navigationStore)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: true)
        popup.isBordered = false
        popup.font = .systemFont(ofSize: 12, weight: .regular)
        (popup.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtBottom
        let title = projectStore.selectedProject?.name ?? "Project"
        popup.addItem(withTitle: title)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        popup.item(at: 0)?.image = NSImage(systemSymbolName: "folder.badge.person.crop", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        popup.menu?.delegate = context.coordinator
        popup.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return popup
    }

    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        context.coordinator.projectStore = projectStore
        context.coordinator.navigationStore = navigationStore
        popup.item(at: 0)?.title = projectStore.selectedProject?.name ?? "Project"
    }
}

@MainActor
final class ProjectMenuCoordinator: NSObject, NSMenuDelegate {
    var projectStore: ProjectStore
    var navigationStore: NavigationStore

    init(projectStore: ProjectStore, navigationStore: NavigationStore) {
        self.projectStore = projectStore
        self.navigationStore = navigationStore
        super.init()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        while menu.numberOfItems > 1 {
            menu.removeItem(at: menu.numberOfItems - 1)
        }

        let projects = projectStore.projects
        if projects.isEmpty {
            let empty = NSMenuItem(title: "No Projects Available", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for project in projects {
                let item = NSMenuItem(title: project.name, action: #selector(selectProject(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = project
                item.state = (project.id == projectStore.selectedProject?.id) ? .on : .off
                item.image = NSImage(systemSymbolName: "folder.badge.person.crop", accessibilityDescription: nil)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let manage = NSMenuItem(title: "Manage Projects\u{2026}", action: #selector(manageProjects(_:)), keyEquivalent: "")
        manage.target = self
        manage.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(manage)
    }

    @objc private func selectProject(_ sender: NSMenuItem) {
        guard let project = sender.representedObject as? Project else { return }
        projectStore.selectProject(project)
        navigationStore.selectProject(project)
    }

    @objc private func manageProjects(_ sender: NSMenuItem) {
        ManageProjectsWindowController.shared.present()
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

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

    func makeCoordinator() -> ProjectMenuDelegate {
        ProjectMenuDelegate(projectStore: projectStore, navigationStore: navigationStore)
    }

    func makeNSView(context: Context) -> ProjectButtonContentView {
        let view = ProjectButtonContentView(
            projectName: projectStore.selectedProject?.name ?? "Project",
            subtitle: "Local",
            target: context.coordinator,
            action: #selector(ProjectMenuDelegate.showMenu(_:))
        )
        return view
    }

    func updateNSView(_ view: ProjectButtonContentView, context: Context) {
        context.coordinator.projectStore = projectStore
        context.coordinator.navigationStore = navigationStore
        view.update(
            projectName: projectStore.selectedProject?.name ?? "Project",
            subtitle: "Local"
        )
        // Remove Liquid Glass bezel from the hosting toolbar item
        view.configureToolbarItemPlain()
    }
}

final class ProjectButtonContentView: NSView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    init(projectName: String, subtitle: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        setupViews()
        update(projectName: projectName, subtitle: subtitle)

        let click = NSClickGestureRecognizer(target: target, action: action)
        addGestureRecognizer(click)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.isEditable = false
        subtitleLabel.isBordered = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(nameLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            nameLabel.topAnchor.constraint(equalTo: topAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: -1),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func update(projectName: String, subtitle: String) {
        nameLabel.stringValue = projectName
        subtitleLabel.stringValue = subtitle
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        let width = max(nameLabel.intrinsicContentSize.width, subtitleLabel.intrinsicContentSize.width)
        let height = nameLabel.intrinsicContentSize.height + subtitleLabel.intrinsicContentSize.height - 1
        return NSSize(width: width, height: height)
    }

    override func mouseDown(with event: NSEvent) {
        // Forward to gesture recognizer
        super.mouseDown(with: event)
    }

    /// Find the hosting NSToolbarItem and set its style to `.plain`
    /// to remove the Liquid Glass bezel.
    func configureToolbarItemPlain() {
        guard !didConfigureToolbarItem else { return }
        guard let toolbar = window?.toolbar else { return }
        for item in toolbar.items {
            if item.itemIdentifier.rawValue.contains("project") {
                item.isBordered = false
                if #available(macOS 26.0, *) {
                    item.style = .plain
                }
                didConfigureToolbarItem = true
                return
            }
        }
    }

    private var didConfigureToolbarItem = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Defer to allow toolbar item to fully install
        DispatchQueue.main.async { [weak self] in
            self?.configureToolbarItemPlain()
        }
    }
}

@MainActor
final class ProjectMenuDelegate: NSObject {
    var projectStore: ProjectStore
    var navigationStore: NavigationStore

    init(projectStore: ProjectStore, navigationStore: NavigationStore) {
        self.projectStore = projectStore
        self.navigationStore = navigationStore
        super.init()
    }

    @objc func showMenu(_ sender: Any?) {
        let sourceView: NSView?
        if let gesture = sender as? NSGestureRecognizer {
            sourceView = gesture.view
        } else if let view = sender as? NSView {
            sourceView = view
        } else {
            sourceView = nil
        }

        let menu = NSMenu()

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
                item.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let manage = NSMenuItem(title: "Manage Projects\u{2026}", action: #selector(manageProjects(_:)), keyEquivalent: "")
        manage.target = self
        manage.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(manage)

        if let sourceView {
            let point = NSPoint(x: 0, y: sourceView.bounds.maxY + 4)
            menu.popUp(positioning: nil, at: point, in: sourceView)
        }
    }

    @objc private func selectProject(_ sender: NSMenuItem) {
        guard let project = sender.representedObject as? Project else { return }
        projectStore.selectProject(project)
        navigationStore.selectProject(project)
    }

    @objc private func manageProjects(_ sender: NSMenuItem) {
        ManageConnectionsWindowController.shared.present(initialSection: .projects)
    }
}

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
        Task { await environmentState.connect(to: connection) }
    }

    @objc private func manageConnections(_ sender: NSMenuItem) {
        ManageConnectionsWindowController.shared.present()
    }
}

// MARK: - Connections Menu Button

struct ConnectionsMenuButton: NSViewRepresentable {
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

        let manage = NSMenuItem(title: "Manage Connections\u{2026}", action: #selector(manageConnections(_:)), keyEquivalent: "")
        manage.target = self
        manage.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(manage)

        let quick = NSMenuItem(title: "Quick Connect\u{2026}", action: #selector(quickConnect(_:)), keyEquivalent: "")
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

#endif

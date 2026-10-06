#if DEBUG
import AppKit

/// Script steps that reach the rest of the app: any main-menu item, the Settings window's panes,
/// and a table's structure or diagram tab.
///
///     { "action": "menu", "target": "File/New Query Tab" }     // a menu path; "dumpMenu" prints every path
///     { "action": "settings", "target": "editor" }              // a pane's raw name; "open" opens the window
///     { "action": "structure", "server": "Test MSSQL", "target": "AdventureWorks2022/Sales.SalesOrderHeader" }
///     { "action": "diagram", "server": "Test MSSQL", "target": "AdventureWorks2022/Sales.SalesOrderHeader" }
///     { "action": "manage", "target": "new" }                   // Manage Connections: connections, identities, projects, new, or a connection's name
///     { "action": "structure", "server": "Test MSSQL", "target": "AdventureWorks2022/Sales.SalesOrderHeader#indexes" }  // a section to focus
///     { "action": "structureEdit", "target": "addColumn" }     // or addIndex, addUnique, addForeignKey, addCheck, section:indexes
///     { "action": "close", "target": "settings" }               // closes the front window of that kind
extension AppDirector {
    static let settingsAutomationNotification = Notification.Name("dev.echodb.echo.automation.settings")

    func performWindowAutomationStep(_ step: AutomationScript.Step, connections: [String: SavedConnection]) {
        let connectionID = step.server.flatMap { connections[$0]?.id }
        switch step.action {
        case "menu":
            performAutomationMenu(step.target ?? "")
        case "dumpMenu":
            dumpAutomationMenu(NSApp.mainMenu, path: "")
            fflush(stdout)
        case "settings":
            if step.target == "open" || step.target == nil {
                performAutomationMenu("Echo/Settings")
            } else if let target = step.target {
                NotificationCenter.default.post(name: Self.settingsAutomationNotification, object: nil, userInfo: ["section": target])
            }
        case "structureEdit":
            // Edits the open structure tab in memory (nothing is applied to the server).
            guard let editor = tabStore.activeTab?.structureEditor else { return }
            switch step.target {
            case "addColumn": _ = editor.addColumn()
            case "addIndex": _ = editor.addIndex()
            case "addUnique": _ = editor.addUniqueConstraint()
            case "addForeignKey": _ = editor.addForeignKey()
            case "addCheck": _ = editor.addCheckConstraint()
            default:
                if let name = step.target, name.hasPrefix("section:"),
                   let section = TableStructureSection(rawValue: String(name.dropFirst("section:".count))) {
                    editor.focusSection(section)
                }
            }
        case "manage":
            let target = step.target ?? "connections"
            let controller = ManageConnectionsWindowController.shared
            if let section = ManageSection(rawValue: target) {
                controller.present(initialSection: section)
            } else if target == "new" {
                controller.present(initialSection: .connections, startingNewConnection: true)
            } else if let connection = connections[target] {
                controller.present(initialSection: .connections, selectedConnectionID: connection.id)
            }
        case "structure", "diagram":
            guard let connectionID, let session = environmentState.sessionGroup.sessionForConnection(connectionID),
                  var target = step.target else { return }
            var focus: TableStructureSection?
            if let hash = target.lastIndex(of: "#") {
                focus = TableStructureSection(rawValue: String(target[target.index(after: hash)...]))
                target = String(target[..<hash])
            }
            let parts = target.split(separator: "/", maxSplits: 1).map(String.init)
            let database = parts.count == 2 ? parts[0] : nil
            let qualified = (parts.last ?? target).split(separator: ".", maxSplits: 1).map(String.init)
            guard qualified.count == 2 else { return }
            let object = SchemaObjectInfo(name: qualified[1], schema: qualified[0], type: .table)
            if step.action == "structure" {
                environmentState.openStructureTab(for: session, object: object, focus: focus, databaseName: database)
            } else {
                environmentState.openDiagramTab(for: session, object: object, activeDatabaseName: database)
            }
        case "close":
            let identifier: NSUserInterfaceItemIdentifier? = switch step.target {
            case "settings": AppWindowIdentifier.settings
            case "manage": AppWindowIdentifier.manageConnections
            default: nil
            }
            NSApp.windows.first { $0.identifier == identifier && $0.isVisible }?.close()
        default:
            break
        }
    }

    /// Chooses the menu item the way a click does. Titles are matched without a trailing ellipsis.
    private func performAutomationMenu(_ path: String) {
        var menu = NSApp.mainMenu
        let parts = path.split(separator: "/").map(String.init)
        for (index, title) in parts.enumerated() {
            guard let current = menu, let item = current.items.first(where: { Self.menuTitle($0.title) == Self.menuTitle(title) }) else {
                print("automation-menu not found: \(path)"); fflush(stdout); return
            }
            if index == parts.count - 1 {
                current.performActionForItem(at: current.index(of: item))
            } else {
                menu = item.submenu
            }
        }
    }

    private static func menuTitle(_ title: String) -> String {
        title.trimmingCharacters(in: CharacterSet(charactersIn: ".… ")).lowercased()
    }

    private func dumpAutomationMenu(_ menu: NSMenu?, path: String) {
        for item in menu?.items ?? [] where !item.isSeparatorItem {
            let here = path.isEmpty ? item.title : "\(path)/\(item.title)"
            print("automation-menu \(here)\(item.isEnabled ? "" : " (disabled)")")
            dumpAutomationMenu(item.submenu, path: here)
        }
    }
}
#endif

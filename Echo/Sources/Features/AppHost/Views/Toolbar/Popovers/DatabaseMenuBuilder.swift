import AppKit

#if os(macOS)

@MainActor
enum DatabaseMenuBuilder {

    static func buildMenu(connectionStore: ConnectionStore, environmentState: EnvironmentState) -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = 220

        guard let connectionID = connectionStore.selectedConnectionID,
              let session = environmentState.sessionGroup.sessionForConnection(connectionID) else {
            let emptyItem = NSMenuItem(title: "No Connection", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return menu
        }

        let databases = session.databaseStructure?.databases ?? []
        let selectedName = session.selectedDatabaseName

        if databases.isEmpty {
            let loadingItem = NSMenuItem(title: "Loading databases", action: nil, keyEquivalent: "")
            loadingItem.isEnabled = false
            menu.addItem(loadingItem)
        } else {
            for db in databases {
                let item = NSMenuItem(
                    title: db.name,
                    action: #selector(DatabaseMenuActions.selectDatabase(_:)),
                    keyEquivalent: ""
                )
                item.target = DatabaseMenuActions.shared
                item.representedObject = DatabaseMenuContext(
                    databaseName: db.name,
                    session: session,
                    environmentState: environmentState
                )

                if db.name == selectedName {
                    item.state = .on
                }

                item.image = NSImage(systemSymbolName: "cylinder", accessibilityDescription: nil)?
                    .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))

                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(
            title: "Refresh List",
            action: #selector(DatabaseMenuActions.refreshDatabases(_:)),
            keyEquivalent: ""
        )
        refreshItem.target = DatabaseMenuActions.shared
        refreshItem.representedObject = DatabaseMenuContext(
            databaseName: "",
            session: session,
            environmentState: environmentState
        )
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
        menu.addItem(refreshItem)

        return menu
    }
}

// MARK: - Menu Context

final class DatabaseMenuContext: @unchecked Sendable {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState

    init(databaseName: String, session: ConnectionSession, environmentState: EnvironmentState) {
        self.databaseName = databaseName
        self.session = session
        self.environmentState = environmentState
    }
}

// MARK: - Menu Actions

@MainActor
final class DatabaseMenuActions: NSObject {
    static let shared = DatabaseMenuActions()

    @objc func selectDatabase(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? DatabaseMenuContext else { return }
        Task {
            await context.environmentState.loadSchemaForDatabase(context.databaseName, connectionSession: context.session)
        }
    }

    @objc func refreshDatabases(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? DatabaseMenuContext else { return }
        Task {
            await context.environmentState.refreshDatabaseStructure(for: context.session.id, scope: .full)
        }
    }
}

#endif

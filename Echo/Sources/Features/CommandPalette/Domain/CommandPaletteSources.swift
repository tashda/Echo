import Foundation
import EchoSense

/// Builds the palette's rows from the app's state: actions, open tabs, clipboard history and
/// snippets, plus a row for each object the global search finds (plan K4).
@MainActor
struct CommandPaletteSources {
    let environmentState: EnvironmentState
    let tabStore: TabStore
    let connectionStore: ConnectionStore
    let navigationStore: NavigationStore
    let clipboardHistory: ClipboardHistoryStore
    /// Turns the palette to this window's tabs (round 35.1).
    let showTabOverview: @MainActor () -> Void

    /// Rows are built when the palette opens; history is capped so matching stays instant.
    static let historyLimit = 50

    func localItems() -> [CommandPaletteItem] {
        actionItems() + tabItems()
    }

    func objectItem(for result: GlobalSearchResult) -> CommandPaletteItem? {
        if case .queryTab = result.payload { return nil }
        let opener = SearchResultOpener(environmentState: environmentState, navigationStore: navigationStore, tabStore: tabStore)
        let environmentState = environmentState
        return CommandPaletteItem(
            id: "object.\(result.id)",
            section: .objects,
            title: result.title,
            subtitle: [result.subtitle, "\(result.serverName) · \(result.databaseName)"].compactMap { $0 }.joined(separator: " · "),
            systemImage: result.category.systemImage,
            perform: {
                guard let session = environmentState.sessionGroup.activeSessions
                    .first(where: { $0.id == result.connectionSessionID }) else { return }
                opener.open(result, in: session)
            }
        )
    }

    private static func name(of connection: SavedConnection) -> String {
        connection.connectionName.isEmpty ? connection.host : connection.connectionName
    }

    // MARK: - Actions

    private func actionItems() -> [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []
        let environmentState = environmentState

        // Round 35.1 (TO6): the tab overview lives in the palette; this row turns it to the tabs.
        if tabStore.hasTabs {
            items.append(CommandPaletteItem(
                id: "tabOverview", section: .actions, title: "Tab Overview", subtitle: "⇧⌘O",
                systemImage: "square.grid.2x2", keywords: "show all open tabs", keepsPaletteOpen: true,
                perform: showTabOverview
            ))
        }

        if let tab = tabStore.activeTab, tab.query != nil {
            for mode in QueryRunMode.allCases where tab.canRun(mode) {
                items.append(CommandPaletteItem(
                    id: "run.\(mode)", section: .actions, title: mode.title, subtitle: tab.title,
                    systemImage: mode.systemImage, perform: { tab.run(mode) }
                ))
            }
            for database in environmentState.switchableDatabaseNames(for: tab) where database != tab.activeDatabaseName {
                items.append(CommandPaletteItem(
                    id: "switch.\(database)", section: .actions, title: "Switch Database to \(database)",
                    subtitle: Self.name(of: tab.connection), systemImage: "cylinder.split.1x2",
                    keywords: "use database \(database)",
                    perform: { environmentState.switchDatabase(database, for: tab) }
                ))
            }
        }

        for session in environmentState.sessionGroup.activeSessions {
            let name = Self.name(of: session.connection)
            items.append(CommandPaletteItem(
                id: "newquery.\(session.id)", section: .actions, title: "New Query in \(name)",
                subtitle: session.connection.host, systemImage: "plus.square.on.square",
                perform: { environmentState.openQueryTab(for: session) }
            ))
        }

        let connectedIDs = Set(environmentState.sessionGroup.activeSessions.map(\.connection.id))
        for connection in connectionStore.connections where !connectedIDs.contains(connection.id) {
            items.append(CommandPaletteItem(
                id: "connect.\(connection.id)", section: .actions, title: "Connect to \(Self.name(of: connection))",
                subtitle: connection.host, systemImage: "bolt.horizontal",
                perform: { environmentState.connectToNewSession(to: connection) }
            ))
        }
        return items
    }

    // MARK: - Tabs, history, snippets

    private func tabItems() -> [CommandPaletteItem] {
        let tabStore = tabStore
        let environmentState = environmentState
        return tabStore.tabs.map { tab in
            CommandPaletteItem(
                id: "tab.\(tab.id)", section: .tabs, title: tab.title,
                subtitle: [Self.name(of: tab.connection), tab.activeDatabaseName].compactMap { $0 }.joined(separator: " · "),
                systemImage: tab.query != nil ? "doc.text" : "square.on.square",
                perform: {
                    environmentState.sessionGroup.setActiveSession(tab.connectionSessionID)
                    tabStore.activeTabId = tab.id
                }
            )
        }
    }

}

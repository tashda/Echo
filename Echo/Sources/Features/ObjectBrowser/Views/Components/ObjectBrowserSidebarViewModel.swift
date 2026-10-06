import Foundation

@MainActor @Observable
final class ObjectBrowserSidebarViewModel {
    var expandedNodeIDs: Set<String> = []
    var selectedNodeID: String?
    var hideOfflineDatabasesBySession: [UUID: Bool] = [:]
    /// The column row being renamed in place, and what to do with the new name.
    var renamingColumnNodeID: String?
    @ObservationIgnored var onColumnRename: ((ExplorerColumnOwner, ColumnInfo, String) -> Void)?
    /// Folders whose filter field is open, with what it says (round 42.6). Not kept between launches.
    var folderFilters: [String: String] = [:]
    /// Show the rarer object folders even when empty (round 42.6, Show Empty Folders).
    var showsEmptyFolders = ExplorerStateStore.bool(forKey: "echo.sidebar.showsEmptyFolders") ?? false {
        didSet { ExplorerStateStore.set(showsEmptyFolders, forKey: "echo.sidebar.showsEmptyFolders") }
    }
    var revealedNodeID: String?
    var revealRequestID = 0
    /// False makes the next reveal a jump (a dock switch returning to its place, round 19).
    var revealAnimated = true
    /// Servers whose rows are faded out while their dock switches sections (round 19, S3).
    var dockFadingConnectionIDs: Set<UUID> = []
    /// Servers mid-switch: their rows swap without transitions of their own, so the old section
    /// can never show again while it is removed.
    var dockSwitchingConnectionIDs: Set<UUID> = []
    /// Servers whose new rows wait, invisible, until the card has its new size.
    var dockHiddenRowsConnectionIDs: Set<UUID> = []
    /// Servers whose cards are folding or opening (round 30.2): set just before the change, so
    /// the rows that leave already carry the fold's transition, and cleared when it ends.
    var foldingConnectionIDs: Set<UUID> = []
    /// Servers whose card is leaving the tree (minimized) or coming back (restored): the card and all
    /// its rows move as one piece, and the cards below and the trail's item move with it on the house
    /// spring (round 55), not on the folder curve.
    var travellingConnectionIDs: Set<UUID> = []
    /// Counts folds, so one that ends while a newer one runs leaves the newer one's cards alone.
    @ObservationIgnored var foldGeneration = 0
    /// The card about to close, so the tree first brings its header to its own place.
    var foldAnchor: ExplorerFoldAnchor?
    var highlightedNodeID: String?
    var highlightPulse = false
    /// Everything loaded for folders beyond the schema (logins, jobs, queues…), by source.
    var childSources: [ExplorerSourceKey: ExplorerSourceState] = [:]

    @ObservationIgnored var initializedConnectionIDs: Set<UUID> = []
    /// The section each server's dock shows (TC1), by connection.
    var dockSelections: [UUID: String] = [:]

    private static func hideOfflineKey(for connectionID: UUID) -> String {
        "echo.sidebar.hideOffline.\(connectionID.uuidString)"
    }

    func setHideOffline(_ hidden: Bool, for connectionID: UUID) {
        hideOfflineDatabasesBySession[connectionID] = hidden
        ExplorerStateStore.set(hidden, forKey: Self.hideOfflineKey(for: connectionID))
    }

    func synchronizeDefaults(
        sessions: [ConnectionSession],
        autoExpandSectionsForDatabaseType: (DatabaseType) -> Set<SidebarAutoExpandSection>,
        hideOfflineDefault: Bool = false
    ) {
        let validConnectionIDs = Set(sessions.map(\.connection.id))
        initializedConnectionIDs = initializedConnectionIDs.intersection(validConnectionIDs)
        var expanded = expandedNodeIDs

        for session in sessions where !initializedConnectionIDs.contains(session.connection.id) {
            initializedConnectionIDs.insert(session.connection.id)

            // Load per-connection hide offline state from UserDefaults, falling back to global default
            let key = Self.hideOfflineKey(for: session.connection.id)
            if let saved = ExplorerStateStore.bool(forKey: key) {
                hideOfflineDatabasesBySession[session.connection.id] = saved
            } else {
                hideOfflineDatabasesBySession[session.connection.id] = hideOfflineDefault
            }

            expanded.insert(Self.serverNodeID(connectionID: session.connection.id))

            let autoExpand = autoExpandSectionsForDatabaseType(session.connection.databaseType)
            if autoExpand.contains(.databases) {
                expanded.insert(Self.databasesFolderNodeID(connectionID: session.connection.id))
            }
            if autoExpand.contains(.security) {
                expanded.insert(
                    Self.serverFolderNodeID(connectionID: session.connection.id, kind: .serverSecurity)
                )
            }
            if autoExpand.contains(.management) {
                expanded.insert(
                    Self.serverFolderNodeID(connectionID: session.connection.id, kind: .management)
                )
            }
        }

        expandedNodeIDs = expanded
    }

    func setExpanded(_ isExpanded: Bool, nodeID: String) {
        var expanded = expandedNodeIDs
        if isExpanded {
            expanded.insert(nodeID)
        } else {
            expanded.remove(nodeID)
        }
        expandedNodeIDs = expanded
    }

    /// Opens or minimizes a server's card. Cards open and close independently.
    func setServerExpanded(_ isExpanded: Bool, connectionID: UUID) {
        setExpanded(isExpanded, nodeID: Self.serverNodeID(connectionID: connectionID))
    }

    /// Which servers' cards are minimized, so they leave the tree and the trail lists them below the hairline.
    func minimizedServers(sessions: [ConnectionSession], movesToTrail: Bool) -> ExplorerMinimizedServers {
        ExplorerMinimizedServers(
            sessionConnectionIDs: sessions.map(\.connection.id),
            initializedConnectionIDs: initializedConnectionIDs,
            expandedNodeIDs: expandedNodeIDs,
            movesToTrail: movesToTrail
        )
    }

    func toggleExpanded(nodeID: String) -> Bool {
        var expanded = expandedNodeIDs
        if expanded.contains(nodeID) {
            expanded.remove(nodeID)
            expandedNodeIDs = expanded
            return false
        } else {
            expanded.insert(nodeID)
            expandedNodeIDs = expanded
            return true
        }
    }

    func isExpanded(_ nodeID: String) -> Bool {
        expandedNodeIDs.contains(nodeID)
    }

    func revealAndPulse(nodeID: String) {
        revealedNodeID = nodeID
        revealRequestID &+= 1
        highlightedNodeID = nodeID
        highlightPulse.toggle()
    }
}

extension ObjectBrowserSidebarViewModel {
    func sourceState(_ key: ExplorerSourceKey) -> ExplorerSourceState {
        childSources[key] ?? ExplorerSourceState()
    }

    func items(_ key: ExplorerSourceKey, kind: ExplorerNodeKind) -> [ExplorerItem] {
        childSources[key]?.items[kind] ?? []
    }

    func beginLoading(_ key: ExplorerSourceKey) {
        childSources[key, default: ExplorerSourceState()].isLoading = true
    }

    /// Stores a finished load. A failed load stores empty lists, so the folders say they're empty.
    func finishLoading(_ key: ExplorerSourceKey, items: [ExplorerNodeKind: [ExplorerItem]]) {
        var state = childSources[key] ?? ExplorerSourceState()
        state.items = items
        state.hasLoaded = true
        state.isLoading = false
        childSources[key] = state
    }

    func endLoading(_ key: ExplorerSourceKey) {
        childSources[key]?.isLoading = false
    }
}

extension ObjectBrowserSidebarViewModel {
    nonisolated static func serverNodeID(connectionID: UUID) -> String {
        "\(connectionID.uuidString)#server"
    }

    static func databasesFolderNodeID(connectionID: UUID) -> String {
        "\(connectionID.uuidString)#folder#databases"
    }

    static func databaseNodeID(connectionID: UUID, databaseName: String) -> String {
        ExplorerSidebarIdentity.database(connectionID: connectionID, databaseName: databaseName)
    }

    static func objectGroupNodeID(
        connectionID: UUID,
        databaseName: String,
        objectType: SchemaObjectInfo.ObjectType
    ) -> String {
        "\(connectionID.uuidString)#db#\(databaseName)#group#\(objectType.rawValue)"
    }

    /// A server-level folder (a section heading).
    static func serverFolderNodeID(connectionID: UUID, kind: ExplorerNodeKind) -> String {
        if kind == .databases { return databasesFolderNodeID(connectionID: connectionID) }
        return "\(connectionID.uuidString)#server-folder#\(kind.idComponent)"
    }

    static func actionNodeID(connectionID: UUID, parentID: String?, kind: ExplorerNodeKind) -> String {
        "\(parentID ?? connectionID.uuidString)#action#\(kind.idComponent)"
    }

    /// A folder directly inside a database.
    static func databaseFolderNodeID(connectionID: UUID, databaseName: String, kind: ExplorerNodeKind) -> String {
        "\(connectionID.uuidString)#db#\(databaseName)#folder#\(kind.idComponent)"
    }

    static func databaseSubfolderNodeID(parentID: String, title: String) -> String {
        "\(parentID)#subfolder#\(title)"
    }

    static func databaseItemNodeID(parentID: String, title: String) -> String {
        "\(parentID)#item#\(title)"
    }

    static func infoNodeID(parentID: String, title: String) -> String {
        "\(parentID)#info#\(title)"
    }

    static func loadingNodeID(parentID: String) -> String {
        "\(parentID)#loading"
    }
}

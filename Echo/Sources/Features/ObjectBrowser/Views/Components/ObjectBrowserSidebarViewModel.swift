import Foundation

@MainActor @Observable
final class ObjectBrowserSidebarViewModel {
    var expandedNodeIDs: Set<String> = []
    var selectedNodeID: String?
    var hideOfflineDatabasesBySession: [UUID: Bool] = [:]
    var revealedNodeID: String?
    var revealRequestID = 0
    /// False makes the next reveal a jump (a dock switch returning to its place, round 19).
    var revealAnimated = true
    /// Servers whose rows are faded out while their dock switches sections (round 19, S3).
    var dockFadingConnectionIDs: Set<UUID> = []
    var highlightedNodeID: String?
    var highlightPulse = false
    /// Everything loaded for folders beyond the schema (logins, jobs, queues…), by source.
    var childSources: [ExplorerSourceKey: ExplorerSourceState] = [:]

    @ObservationIgnored var initializedConnectionIDs: Set<UUID> = []
    /// The section each server's dock shows (TC1), by connection.
    var dockSelections: [UUID: String] = [:]
    /// The row at the top of each server's section when it was left, to return to it.
    @ObservationIgnored var dockScrollAnchors: [String: String] = [:]
    /// The row at the top of the tree right now, and its server's connection.
    @ObservationIgnored var topVisibleRow: (id: String, connectionID: UUID?)?

    private static func hideOfflineKey(for connectionID: UUID) -> String {
        "echo.sidebar.hideOffline.\(connectionID.uuidString)"
    }

    func setHideOffline(_ hidden: Bool, for connectionID: UUID) {
        hideOfflineDatabasesBySession[connectionID] = hidden
        UserDefaults.standard.set(hidden, forKey: Self.hideOfflineKey(for: connectionID))
    }

    func synchronizeDefaults(
        sessions: [ConnectionSession],
        autoExpandSectionsForDatabaseType: (DatabaseType) -> Set<SidebarAutoExpandSection>,
        hideOfflineDefault: Bool = false,
        activeConnectionID: UUID? = nil,
        expandOneConnectionAtATime: Bool = false
    ) {
        let validConnectionIDs = Set(sessions.map(\.connection.id))
        initializedConnectionIDs = initializedConnectionIDs.intersection(validConnectionIDs)
        var expanded = expandedNodeIDs
        let rootConnectionID = activeConnectionID ?? sessions.first?.connection.id

        for session in sessions where !initializedConnectionIDs.contains(session.connection.id) {
            initializedConnectionIDs.insert(session.connection.id)

            // Load per-connection hide offline state from UserDefaults, falling back to global default
            let key = Self.hideOfflineKey(for: session.connection.id)
            if let saved = UserDefaults.standard.object(forKey: key) as? Bool {
                hideOfflineDatabasesBySession[session.connection.id] = saved
            } else {
                hideOfflineDatabasesBySession[session.connection.id] = hideOfflineDefault
            }

            if !expandOneConnectionAtATime || session.connection.id == rootConnectionID {
                expanded.insert(Self.serverNodeID(connectionID: session.connection.id))
            }

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

        if expandOneConnectionAtATime, let rootConnectionID {
            let otherServerIDs = sessions
                .map(\.connection.id)
                .filter { $0 != rootConnectionID }
                .map { Self.serverNodeID(connectionID: $0) }
            expanded.subtract(otherServerIDs)
            expanded.insert(Self.serverNodeID(connectionID: rootConnectionID))
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

    func setServerExpanded(
        _ isExpanded: Bool,
        connectionID: UUID,
        sessions: [ConnectionSession],
        collapseOthers: Bool
    ) {
        setServerExpanded(
            isExpanded,
            connectionID: connectionID,
            allConnectionIDs: sessions.map(\.connection.id),
            collapseOthers: collapseOthers
        )
    }

    func setServerExpanded(
        _ isExpanded: Bool,
        connectionID: UUID,
        allConnectionIDs: [UUID],
        collapseOthers: Bool
    ) {
        let serverID = Self.serverNodeID(connectionID: connectionID)
        var expanded = expandedNodeIDs

        if isExpanded {
            if collapseOthers {
                let otherServerIDs = Set(
                    allConnectionIDs
                        .filter { $0 != connectionID }
                        .map { Self.serverNodeID(connectionID: $0) }
                )
                expanded.subtract(otherServerIDs)
            }
            expanded.insert(serverID)
        } else {
            expanded.remove(serverID)
        }

        expandedNodeIDs = expanded
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
    static func serverNodeID(connectionID: UUID) -> String {
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

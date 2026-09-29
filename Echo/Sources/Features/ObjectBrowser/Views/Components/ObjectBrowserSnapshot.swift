import Foundation

@MainActor
enum ObjectBrowserSnapshotBuilder {
    static func buildRoots(
        pendingConnections: [PendingConnection],
        sessions: [ConnectionSession],
        settings: GlobalSettings,
        viewModel: ObjectBrowserSidebarViewModel,
        selectedConnectionID: UUID? = nil
    ) -> [ObjectBrowserNode] {
        let connectionLayoutMode = ObjectBrowserConnectionLayoutMode(
            expandOneConnectionAtATime: settings.sidebarExpandOneConnectionAtATime
        )
        let topSpacer = ObjectBrowserNode(
            id: "explorer-lab#top-spacer",
            row: .topSpacer(connectionLayoutMode.outlineTopSpacerHeight)
        )

        var rows: [ObjectBrowserNode] = [topSpacer]
        // Each server sits on its own card; cards are one gutter apart (the Spacing Between
        // Panes setting), plus the room left below a card's last row.
        let cardSpacing = settings.workspaceGutter.points + LayoutTokens.Workspace.treeCardBottomPadding
        func appendGap(before key: String) {
            guard rows.count > 1 else { return }
            rows.append(ObjectBrowserNode(id: "explorer-lab#gap#\(key)", row: .topSpacer(cardSpacing)))
        }

        if !connectionLayoutMode.showsServerNameInOutline,
           let activeSession = selectedSession(from: sessions, selectedConnectionID: selectedConnectionID) {
            rows.append(contentsOf: serverChildren(
                for: activeSession,
                settings: settings,
                viewModel: viewModel
            ))
        } else {
            for session in sessions {
                appendGap(before: session.connection.id.uuidString)
                let serverID = ObjectBrowserSidebarViewModel.serverNodeID(connectionID: session.connection.id)
                rows.append(
                    ObjectBrowserNode(
                        id: serverID,
                        row: .server(session),
                        children: serverChildren(
                            for: session,
                            settings: settings,
                            viewModel: viewModel
                        )
                    )
                )
            }
        }

        // Servers still connecting, or that failed to, come last, in the rail's order.
        for pending in pendingConnections {
            appendGap(before: "pending#\(pending.id.uuidString)")
            rows.append(
                ObjectBrowserNode(
                    id: "\(pending.id.uuidString)#pending",
                    row: .pendingConnection(pending)
                )
            )
        }

        return rows
    }

    private static func selectedSession(
        from sessions: [ConnectionSession],
        selectedConnectionID: UUID?
    ) -> ConnectionSession? {
        if let selectedConnectionID,
           let selected = sessions.first(where: { $0.connection.id == selectedConnectionID }) {
            return selected
        }
        return sessions.first
    }

    static func serverChildren(
        for session: ConnectionSession,
        settings: GlobalSettings,
        viewModel: ObjectBrowserSidebarViewModel
    ) -> [ObjectBrowserNode] {
        switch session.structureLoadingState {
        case .failed(let message):
            return [
                ObjectBrowserNode(
                    id: "\(session.connection.id.uuidString)#failed",
                    row: .message(message ?? "Failed to load", systemImage: "exclamationmark.triangle.fill", depth: 1)
                )
            ]
        case .idle:
            return [
                ObjectBrowserNode(
                    id: "\(session.connection.id.uuidString)#server-loading",
                    row: .loading("Loading server…", depth: 1)
                )
            ]
        case .loading where session.databaseStructure == nil:
            return [
                ObjectBrowserNode(
                    id: "\(session.connection.id.uuidString)#server-loading",
                    row: .loading("Loading server…", depth: 1)
                )
            ]
        default:
            let structure = session.databaseStructure
            let visibleDatabases = visibleDatabases(
                for: session,
                structure: structure,
                settings: settings,
                hideOffline: viewModel.hideOfflineDatabasesBySession[session.connection.id] ?? false
            )
            let folderID = ObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: session.connection.id)
            let folderChildren = visibleDatabases.map {
                databaseNode(
                    for: session,
                    database: $0,
                    settings: settings,
                    expandedNodeIDs: viewModel.expandedNodeIDs,
                    viewModel: viewModel
                )
            }

            var children = [
                ObjectBrowserNode(
                    id: folderID,
                    row: .databasesFolder(session, count: visibleDatabases.count),
                    children: folderChildren
                )
            ]
            children.append(contentsOf: serverSupplementaryChildren(for: session, viewModel: viewModel))
            return children
        }
    }

    private static func databaseNode(
        for session: ConnectionSession,
        database: DatabaseInfo,
        settings: GlobalSettings,
        expandedNodeIDs: Set<String>,
        viewModel: ObjectBrowserSidebarViewModel
    ) -> ObjectBrowserNode {
        let databaseID = ObjectBrowserSidebarViewModel.databaseNodeID(
            connectionID: session.connection.id,
            databaseName: database.name
        )

        let isLoading = session.schemaLoadsInFlight.contains(session.schemaLoadKey(database.name))

        // A collapsed database's objects are never shown, so they aren't built: with many
        // databases whose schemas load in the background, building them made every render (a
        // rail click, a scroll-driven update) cost thousands of nodes. One placeholder child keeps
        // the database expandable.
        guard expandedNodeIDs.contains(databaseID) else {
            return ObjectBrowserNode(
                id: databaseID,
                row: .database(session, database, isLoading: isLoading),
                children: [
                    ObjectBrowserNode(
                        id: ObjectBrowserSidebarViewModel.loadingNodeID(parentID: databaseID),
                        row: .loading("Expand to load objects…", depth: 2)
                    )
                ]
            )
        }

        let children = databaseChildren(
            for: session,
            database: database,
            settings: settings,
            expandedNodeIDs: expandedNodeIDs,
            isLoading: isLoading,
            viewModel: viewModel
        )

        return ObjectBrowserNode(
            id: databaseID,
            row: .database(session, database, isLoading: isLoading),
            children: children
        )
    }

    private static func databaseChildren(
        for session: ConnectionSession,
        database: DatabaseInfo,
        settings: GlobalSettings,
        expandedNodeIDs: Set<String>,
        isLoading: Bool,
        viewModel: ObjectBrowserSidebarViewModel
    ) -> [ObjectBrowserNode] {
        if isLoading {
            return [
                ObjectBrowserNode(
                    id: ObjectBrowserSidebarViewModel.loadingNodeID(
                        parentID: ObjectBrowserSidebarViewModel.databaseNodeID(
                            connectionID: session.connection.id,
                            databaseName: database.name
                        )
                    ),
                    row: .loading("Loading schema…", depth: 2)
                )
            ]
        }

        guard session.hasLoadedSchema(forDatabase: database.name) else {
            return [
                ObjectBrowserNode(
                    id: ObjectBrowserSidebarViewModel.loadingNodeID(
                        parentID: ObjectBrowserSidebarViewModel.databaseNodeID(
                            connectionID: session.connection.id,
                            databaseName: database.name
                        )
                    ),
                    row: .loading(session.metadataFreshness(forDatabase: database.name) == .failed ? "Schema refresh failed" : "Expand to load objects…", depth: 2)
                )
            ]
        }

        let supportedTypes = SchemaObjectInfo.ObjectType.supported(for: session.connection.databaseType)
        let snapshot = groupedObjects(for: database, supportedTypes: supportedTypes)
        // Empty folders are hidden unless the user asks for them in Settings ▸ Sidebar.
        let visibleTypes = settings.sidebarShowsEmptyFolders
            ? supportedTypes
            : supportedTypes.filter { !(snapshot[$0] ?? []).isEmpty }

        let objectGroupNodes = visibleTypes.map { type in
            let objects = snapshot[type] ?? []
            let groupID = ObjectBrowserSidebarViewModel.objectGroupNodeID(
                connectionID: session.connection.id,
                databaseName: database.name,
                objectType: type
            )
            let showsColumns = type == .table || type == .view || type == .materializedView
            let groupChildren = objects.map { object -> ObjectBrowserNode in
                let objectID = ExplorerSidebarIdentity.object(
                    connectionID: session.connection.id,
                    databaseName: database.name,
                    objectID: object.id
                )
                let columnChildren: [ObjectBrowserNode] = showsColumns && !object.columns.isEmpty
                    ? object.columns.map { col in
                        ObjectBrowserNode(
                            id: "\(objectID)#col#\(col.name)",
                            row: .column(col, objectType: type, depth: 4)
                        )
                    }
                    : []
                return ObjectBrowserNode(
                    id: objectID,
                    row: .object(session, database.name, object),
                    children: columnChildren
                )
            }

            return ObjectBrowserNode(
                id: groupID,
                row: .objectGroup(session, database.name, type, count: objects.count),
                children: groupChildren
            )
        }

        let children = objectGroupNodes + databaseSupplementaryChildren(
            for: session,
            database: database,
            viewModel: viewModel
        )
        guard children.isEmpty else { return children }

        // With empty folders hidden, an empty database says so instead of expanding to nothing.
        let databaseID = ObjectBrowserSidebarViewModel.databaseNodeID(
            connectionID: session.connection.id,
            databaseName: database.name
        )
        return [
            ObjectBrowserNode(
                id: "\(databaseID)#empty",
                row: .infoLeaf("No objects", systemImage: "tray", paletteTitle: "", depth: 2)
            )
        ]
    }
}

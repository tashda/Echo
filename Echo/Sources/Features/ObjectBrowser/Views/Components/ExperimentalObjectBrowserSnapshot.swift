import Foundation

@MainActor
enum ObjectBrowserSnapshotBuilder {
    static func buildRoots(
        pendingConnections: [PendingConnection],
        sessions: [ConnectionSession],
        settings: GlobalSettings,
        viewModel: ObjectBrowserSidebarViewModel
    ) -> [ObjectBrowserNode] {
        let topSpacer = ObjectBrowserNode(
            id: "explorer-lab#top-spacer",
            row: .topSpacer(SpacingTokens.xs)
        )

        var rows: [ObjectBrowserNode] = [topSpacer]

        for pending in pendingConnections {
            rows.append(
                ObjectBrowserNode(
                    id: "\(pending.id.uuidString)#pending",
                    row: .pendingConnection(pending)
                )
            )
        }

        if !pendingConnections.isEmpty && !sessions.isEmpty {
            rows.append(
                ObjectBrowserNode(
                    id: "explorer-lab#pending-gap",
                    row: .topSpacer(SpacingTokens.xs)
                )
            )
        }

        for (index, session) in sessions.enumerated() {
            if index > 0 {
                rows.append(
                    ObjectBrowserNode(
                        id: "explorer-lab#server-gap#\(session.connection.id.uuidString)",
                        row: .topSpacer(SpacingTokens.xs)
                    )
                )
            }

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

        return rows
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

        let objectGroupNodes = supportedTypes.map { type in
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

        return objectGroupNodes + databaseSupplementaryChildren(
            for: session,
            database: database,
            viewModel: viewModel
        )
    }
}

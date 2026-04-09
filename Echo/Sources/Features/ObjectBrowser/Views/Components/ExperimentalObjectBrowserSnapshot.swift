import Foundation

@MainActor
enum ExperimentalObjectBrowserSnapshotBuilder {
    static func buildRoots(
        pendingConnections: [PendingConnection],
        sessions: [ConnectionSession],
        settings: GlobalSettings,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        let topSpacer = ExperimentalObjectBrowserNode(
            id: "explorer-lab#top-spacer",
            row: .topSpacer(SpacingTokens.xs)
        )

        var rows: [ExperimentalObjectBrowserNode] = [topSpacer]

        for pending in pendingConnections {
            rows.append(
                ExperimentalObjectBrowserNode(
                    id: "\(pending.id.uuidString)#pending",
                    row: .pendingConnection(pending)
                )
            )
        }

        if !pendingConnections.isEmpty && !sessions.isEmpty {
            rows.append(
                ExperimentalObjectBrowserNode(
                    id: "explorer-lab#pending-gap",
                    row: .topSpacer(SpacingTokens.xs)
                )
            )
        }

        for (index, session) in sessions.enumerated() {
            if index > 0 {
                rows.append(
                    ExperimentalObjectBrowserNode(
                        id: "explorer-lab#server-gap#\(session.connection.id.uuidString)",
                        row: .topSpacer(SpacingTokens.xs)
                    )
                )
            }

            let serverID = ExperimentalObjectBrowserSidebarViewModel.serverNodeID(connectionID: session.connection.id)
            rows.append(
                ExperimentalObjectBrowserNode(
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
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        switch session.structureLoadingState {
        case .failed(let message):
            return [
                ExperimentalObjectBrowserNode(
                    id: "\(session.connection.id.uuidString)#failed",
                    row: .message(message ?? "Failed to load", systemImage: "exclamationmark.triangle.fill", depth: 1)
                )
            ]
        case .idle:
            return [
                ExperimentalObjectBrowserNode(
                    id: "\(session.connection.id.uuidString)#server-loading",
                    row: .loading("Loading server…", depth: 1)
                )
            ]
        case .loading where session.databaseStructure == nil:
            return [
                ExperimentalObjectBrowserNode(
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
            let folderID = ExperimentalObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: session.connection.id)
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
                ExperimentalObjectBrowserNode(
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
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> ExperimentalObjectBrowserNode {
        let databaseID = ExperimentalObjectBrowserSidebarViewModel.databaseNodeID(
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

        return ExperimentalObjectBrowserNode(
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
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        if isLoading {
            return [
                ExperimentalObjectBrowserNode(
                    id: ExperimentalObjectBrowserSidebarViewModel.loadingNodeID(
                        parentID: ExperimentalObjectBrowserSidebarViewModel.databaseNodeID(
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
                ExperimentalObjectBrowserNode(
                    id: ExperimentalObjectBrowserSidebarViewModel.loadingNodeID(
                        parentID: ExperimentalObjectBrowserSidebarViewModel.databaseNodeID(
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
            let groupID = ExperimentalObjectBrowserSidebarViewModel.objectGroupNodeID(
                connectionID: session.connection.id,
                databaseName: database.name,
                objectType: type
            )
            let groupChildren = objects.map {
                ExperimentalObjectBrowserNode(
                    id: ExplorerSidebarIdentity.object(
                        connectionID: session.connection.id,
                        databaseName: database.name,
                        objectID: $0.id
                    ),
                    row: .object(session, database.name, $0)
                )
            }

            return ExperimentalObjectBrowserNode(
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

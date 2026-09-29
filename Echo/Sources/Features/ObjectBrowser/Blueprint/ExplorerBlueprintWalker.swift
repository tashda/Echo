import Foundation

/// Turns a server's blueprint and what has loaded so far into Explorer nodes. It knows nothing
/// about database types: everything specific lives in the blueprints.
@MainActor
struct ExplorerBlueprintWalker {
    /// Where in the tree an entry is being built.
    enum Place {
        /// Directly under the server's name: folders become section headings.
        case server
        /// Directly inside a database.
        case database(DatabaseInfo)
        /// Inside another folder.
        case nested(parentID: String, database: DatabaseInfo?)

        var database: DatabaseInfo? {
            switch self {
            case .server: nil
            case .database(let database): database
            case .nested(_, let database): database
            }
        }
    }

    let session: ConnectionSession
    let settings: GlobalSettings
    let viewModel: ObjectBrowserSidebarViewModel

    private var connectionID: UUID { session.connection.id }
    private var blueprint: ExplorerBlueprint { .blueprint(for: session.connection.databaseType) }

    func nodes(
        for entries: [ExplorerBlueprintNode],
        in place: Place,
        source: ExplorerChildSource? = nil
    ) -> [ObjectBrowserNode] {
        entries.flatMap { nodes(for: $0, in: place, source: source) }
    }

    private func nodes(for entry: ExplorerBlueprintNode, in place: Place, source: ExplorerChildSource?) -> [ObjectBrowserNode] {
        switch entry {
        case .databases:
            return [databasesSection()]
        case .group(let kind, let ownSource, let hidesWhenEmpty, let children):
            return folderNode(kind, source: ownSource ?? source, hidesWhenEmpty: hidesWhenEmpty, children: children, in: place)
        case .items(let kind):
            return itemNodes(kind, source: source, in: place)
        case .objectFolderList(let kinds):
            guard let database = place.database else { return [] }
            return objectFolderNodes(kinds, database: database)
        case .action(let kind):
            return [ObjectBrowserNode(
                id: ObjectBrowserSidebarViewModel.actionNodeID(connectionID: connectionID, parentID: parentID(of: place), kind: kind),
                row: .action(session, kind)
            )]
        case .onlineOnly(let children):
            guard place.database?.isOnline == true else { return [] }
            return nodes(for: children, in: place, source: source)
        }
    }

    // MARK: - Folders and items

    private func folderNode(
        _ kind: ExplorerNodeKind,
        source: ExplorerChildSource?,
        hidesWhenEmpty: Bool,
        children: [ExplorerBlueprintNode],
        in place: Place
    ) -> [ObjectBrowserNode] {
        let id = folderID(kind, in: place)
        let key = sourceKey(source, database: place.database)
        let itemCount = children.reduce(0) { total, child in
            guard case .items(let listed) = child, let key else { return total }
            return total + viewModel.items(key, kind: listed).count
        }
        if hidesWhenEmpty && itemCount == 0 { return [] }

        let folder = ExplorerFolder(
            kind: kind,
            session: session,
            databaseName: place.database?.name,
            count: itemCount > 0 ? itemCount : nil,
            isLoading: key.map { viewModel.sourceState($0).isLoading } ?? false,
            source: source
        )
        let childNodes = nodes(for: children, in: .nested(parentID: id, database: place.database), source: source)
        let row: ObjectBrowserNode.Row = if case .server = place { .section(folder) } else { .folder(folder) }
        return [ObjectBrowserNode(id: id, row: row, children: childNodes)]
    }

    /// A folder's loaded items; while they load, a shimmer; when there are none, a line saying so.
    private func itemNodes(_ kind: ExplorerNodeKind, source: ExplorerChildSource?, in place: Place) -> [ObjectBrowserNode] {
        let parentID = parentID(of: place) ?? connectionID.uuidString
        guard let key = sourceKey(source, database: place.database) else { return [] }
        let items = viewModel.items(key, kind: kind)
        guard items.isEmpty else {
            return items.map {
                ObjectBrowserNode(
                    id: ObjectBrowserSidebarViewModel.databaseItemNodeID(parentID: parentID, title: $0.id),
                    row: .item(ExplorerItemRow(kind: kind.itemKind, session: session, databaseName: place.database?.name, item: $0))
                )
            }
        }
        if viewModel.sourceState(key).isLoading {
            return [ObjectBrowserNode(id: ObjectBrowserSidebarViewModel.loadingNodeID(parentID: parentID), row: .loading(kind.loadingTitle))]
        }
        return [ObjectBrowserNode(
            id: ObjectBrowserSidebarViewModel.infoNodeID(parentID: parentID, title: kind.emptyTitle),
            row: .placeholder(kind.emptyTitle, kind: kind.itemKind)
        )]
    }

    private func folderID(_ kind: ExplorerNodeKind, in place: Place) -> String {
        switch place {
        case .server:
            ObjectBrowserSidebarViewModel.serverFolderNodeID(connectionID: connectionID, kind: kind)
        case .database(let database):
            ObjectBrowserSidebarViewModel.databaseFolderNodeID(connectionID: connectionID, databaseName: database.name, kind: kind)
        case .nested(let parentID, _):
            ObjectBrowserSidebarViewModel.databaseSubfolderNodeID(parentID: parentID, title: kind.title)
        }
    }

    private func parentID(of place: Place) -> String? {
        switch place {
        case .server: nil
        case .database(let database):
            ObjectBrowserSidebarViewModel.databaseNodeID(connectionID: connectionID, databaseName: database.name)
        case .nested(let parentID, _): parentID
        }
    }

    private func sourceKey(_ source: ExplorerChildSource?, database: DatabaseInfo?) -> ExplorerSourceKey? {
        source.map { ExplorerSourceKey(connectionID: connectionID, databaseName: database?.name, source: $0) }
    }

    // MARK: - Databases

    private func databasesSection() -> ObjectBrowserNode {
        let databases = ObjectBrowserSnapshotBuilder.visibleDatabases(
            for: session,
            structure: session.databaseStructure,
            settings: settings,
            hideOffline: viewModel.hideOfflineDatabasesBySession[connectionID] ?? false
        )
        let folder = ExplorerFolder(
            kind: .databases,
            session: session,
            databaseName: nil,
            count: databases.count,
            isLoading: false,
            source: nil
        )
        return ObjectBrowserNode(
            id: ObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: connectionID),
            row: .section(folder),
            children: databases.map(databaseNode)
        )
    }

    private func databaseNode(_ database: DatabaseInfo) -> ObjectBrowserNode {
        let databaseID = ObjectBrowserSidebarViewModel.databaseNodeID(connectionID: connectionID, databaseName: database.name)
        let isLoading = session.schemaLoadsInFlight.contains(session.schemaLoadKey(database.name))
        let row = ObjectBrowserNode.Row.database(session, database, isLoading: isLoading)

        // A collapsed database's objects are never shown, so they aren't built: with many
        // databases whose schemas load in the background, building them made every render (a
        // rail click, a scroll-driven update) cost thousands of nodes. One placeholder child keeps
        // the database expandable.
        guard viewModel.expandedNodeIDs.contains(databaseID) else {
            return ObjectBrowserNode(id: databaseID, row: row, children: [
                ObjectBrowserNode(id: ObjectBrowserSidebarViewModel.loadingNodeID(parentID: databaseID), row: .loading("Loading objects"))
            ])
        }
        return ObjectBrowserNode(id: databaseID, row: row, children: databaseChildren(database, databaseID: databaseID, isLoading: isLoading))
    }

    private func databaseChildren(_ database: DatabaseInfo, databaseID: String, isLoading: Bool) -> [ObjectBrowserNode] {
        let loadingID = ObjectBrowserSidebarViewModel.loadingNodeID(parentID: databaseID)
        if isLoading {
            return [ObjectBrowserNode(id: loadingID, row: .loading("Loading schema"))]
        }
        guard session.hasLoadedSchema(forDatabase: database.name) else {
            let row: ObjectBrowserNode.Row = session.metadataFreshness(forDatabase: database.name) == .failed
                ? .message("Schema refresh failed", systemImage: "exclamationmark.triangle")
                : .loading("Loading objects")
            return [ObjectBrowserNode(id: loadingID, row: row)]
        }

        let children = nodes(for: blueprint.database, in: .database(database))
        guard children.isEmpty else { return children }
        // With empty folders hidden, an empty database says so instead of expanding to nothing.
        return [ObjectBrowserNode(id: "\(databaseID)#empty", row: .placeholder("No objects", kind: nil))]
    }

    /// One folder per object type, in the blueprint's order. Empty folders are hidden unless the
    /// user asks for them in Settings › Sidebar.
    private func objectFolderNodes(_ kinds: [ExplorerNodeKind], database: DatabaseInfo) -> [ObjectBrowserNode] {
        let types = kinds.compactMap(\.objectType)
        let grouped = ObjectBrowserSnapshotBuilder.groupedObjects(for: database, supportedTypes: types)
        let visibleTypes = settings.sidebarShowsEmptyFolders ? types : types.filter { !(grouped[$0] ?? []).isEmpty }

        return visibleTypes.map { type in
            let objects = grouped[type] ?? []
            let showsColumns = type == .table || type == .view || type == .materializedView
            let objectNodes = objects.map { object -> ObjectBrowserNode in
                let objectID = ExplorerSidebarIdentity.object(connectionID: connectionID, databaseName: database.name, objectID: object.id)
                let columns = showsColumns
                    ? object.columns.map { ObjectBrowserNode(id: "\(objectID)#col#\($0.name)", row: .column($0)) }
                    : []
                return ObjectBrowserNode(id: objectID, row: .object(session, database.name, object), children: columns)
            }
            let folder = ExplorerFolder(
                kind: ExplorerNodeKind(objectFolderFor: type),
                session: session,
                databaseName: database.name,
                count: objects.count,
                isLoading: false,
                source: nil
            )
            return ObjectBrowserNode(
                id: ObjectBrowserSidebarViewModel.objectGroupNodeID(connectionID: connectionID, databaseName: database.name, objectType: type),
                row: .folder(folder),
                children: objectNodes
            )
        }
    }
}

import Foundation

extension ObjectBrowserNode {
    /// What decides whether a row is drawn again (`ObjectBrowserOutlineView.RowKey`).
    ///
    /// The tree is rebuilt, node by node, whenever anything it reads changes, so a node says nothing
    /// by being new. Each kind that appears by the hundred (databases, folders, objects, columns,
    /// items and the small status rows) says what it draws and what activating it needs, and
    /// nothing else: a database's row does not change because its schemas arrived. The other kinds
    /// (the server's header, the dock, a column being renamed, a pending connection) are drawn
    /// again with every new node, as before.
    ///
    /// A row that is not drawn again keeps the node it was drawn from, so the key has to hold
    /// everything the row draws and everything its activation reads from the node.
    nonisolated enum RenderKey: Hashable, Sendable {
        /// Not comparable by content: a new node is a new row.
        case instance(ObjectIdentifier)
        case spacer(CGFloat)
        case database(id: String, connection: UUID, name: String, state: String?, hasAccess: Bool?, hasChildren: Bool)
        case folder(id: String, connection: UUID, kind: ExplorerNodeKind, databaseName: String?, count: Int?, isLoading: Bool, hasChildren: Bool)
        case object(id: String, connection: UUID, databaseName: String, object: SchemaObjectInfo, hasChildren: Bool)
        case column(id: String, column: ColumnInfo, databaseType: DatabaseType)
        case item(id: String, connection: UUID, kind: ExplorerNodeKind, databaseName: String?, itemID: String, name: String,
                  detail: String?, isDisabled: Bool, symbol: String?)
        case action(id: String, connection: UUID, kind: ExplorerNodeKind, databaseName: String?)
        case placeholder(id: String, title: String, kind: ExplorerNodeKind?)
        case loading(id: String, title: String, skeleton: Bool)
        case message(id: String, title: String, systemImage: String)
    }

    var renderKey: RenderKey {
        switch row {
        case .topSpacer(let height):
            return .spacer(height)
        case .database(let session, let database):
            return .database(id: id, connection: session.connection.id, name: database.name, state: database.stateDescription,
                             hasAccess: database.hasAccess, hasChildren: !children.isEmpty)
        case .folder(let folder):
            return .folder(id: id, connection: folder.session.connection.id, kind: folder.kind, databaseName: folder.databaseName,
                           count: folder.count, isLoading: folder.isLoading, hasChildren: !children.isEmpty)
        case .object(let session, let databaseName, let object):
            return .object(id: id, connection: session.connection.id, databaseName: databaseName, object: object,
                           hasChildren: !children.isEmpty)
        case .column(let column, let owner):
            guard !owner.isRenaming else { return .instance(ObjectIdentifier(self)) }
            return .column(id: id, column: column, databaseType: owner.session.connection.databaseType)
        case .item(let item):
            return .item(id: id, connection: item.session.connection.id, kind: item.kind, databaseName: item.databaseName,
                         itemID: item.item.id, name: item.item.name, detail: item.item.detail,
                         isDisabled: item.item.isDisabled, symbol: item.item.symbol)
        case .action(let session, let kind, let databaseName):
            return .action(id: id, connection: session.connection.id, kind: kind, databaseName: databaseName)
        case .placeholder(let title, let kind):
            return .placeholder(id: id, title: title, kind: kind)
        case .loading(let title, let style):
            return .loading(id: id, title: title, skeleton: style == .skeleton)
        case .message(let title, let systemImage):
            return .message(id: id, title: title, systemImage: systemImage)
        case .pendingConnection, .server, .section, .filter, .dock:
            return .instance(ObjectIdentifier(self))
        }
    }
}

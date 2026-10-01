import Foundation

/// A folder row: a section heading at server level, or a folder inside it.
struct ExplorerFolder {
    let kind: ExplorerNodeKind
    let session: ConnectionSession
    let databaseName: String?
    /// Items listed directly in the folder; hidden when zero or unknown.
    let count: Int?
    let isLoading: Bool
    /// Where the folder's items load from, its own or its parent's.
    let source: ExplorerChildSource?

    var sourceKey: ExplorerSourceKey? {
        source.map { ExplorerSourceKey(connectionID: session.connection.id, databaseName: databaseName, source: $0) }
    }
}

/// A loaded item row (a login, a job, a queue…).
struct ExplorerItemRow {
    let kind: ExplorerNodeKind
    let session: ConnectionSession
    let databaseName: String?
    let item: ExplorerItem
}

/// How a loading row looks (round 16): a section's first load shows one spinner row (folders
/// first); a folder or database loading its contents shows a quiet skeleton.
enum ExplorerLoadingStyle {
    case spinnerRow
    case skeleton

    /// How many row slots it takes.
    var rowSlots: Int {
        switch self {
        case .spinnerRow: 1
        case .skeleton: LayoutTokens.Shimmer.explorerRowCount
        }
    }
}

@MainActor
final class ObjectBrowserNode: NSObject {
    enum Row {
        case topSpacer(CGFloat)
        case pendingConnection(PendingConnection)
        case server(ConnectionSession)
        /// A server-level folder drawn as a heading (Databases, Security…).
        case section(ExplorerFolder)
        case database(ConnectionSession, DatabaseInfo, isLoading: Bool)
        case folder(ExplorerFolder)
        case object(ConnectionSession, String, SchemaObjectInfo)
        case column(ColumnInfo)
        case item(ExplorerItemRow)
        /// A tool that opens a tab, a window or a sheet; inside a database it knows which one
        /// (Security Overview, round 38).
        case action(ConnectionSession, ExplorerNodeKind, databaseName: String?)
        /// Says a folder is empty ("No logins").
        case placeholder(String, kind: ExplorerNodeKind?)
        /// Something still loading: one spinner row, or skeleton rows (round 16).
        case loading(String, style: ExplorerLoadingStyle)
        case message(String, systemImage: String)
        /// The section dock under a server's name (TC1): which of the server's sections it shows.
        case dock(ConnectionSession, ExplorerDockLayout, selectedID: String)
    }

    let id: String
    var row: Row
    var children: [ObjectBrowserNode]

    init(id: String, row: Row, children: [ObjectBrowserNode] = []) {
        self.id = id
        self.row = row
        self.children = children
    }
}

extension ObjectBrowserNode.Row {
    /// Extra height of a server header row over an ordinary row: its top padding and the
    /// product line under the name (round 16).
    static let serverHeaderExtraHeight: CGFloat = SpacingTokens.xs + SpacingTokens.sm

    /// Extra row-slot height for connection group headers and server-level section headings.
    var extraSlotHeight: CGFloat {
        switch self {
        case .server: return Self.serverHeaderExtraHeight
        case .pendingConnection: return SpacingTokens.xs
        case .section: return LayoutTokens.Workspace.treeSectionTopPadding
        case .dock: return LayoutTokens.ExplorerDock.extraHeight
        default: return 0
        }
    }
}

import Foundation

/// What one database type's Explorer tree shows, in order: the server-level sections under the
/// server's name, and the folders inside each database. The order written in a blueprint is the
/// order in the tree. One file per database type (`ExplorerBlueprint+SQLServer.swift` …); the
/// snapshot builder turns a blueprint and the loaded data into rows.
nonisolated struct ExplorerBlueprint: Sendable {
    let server: [ExplorerBlueprintNode]
    let database: [ExplorerBlueprintNode]
    /// The server-level sections the section dock shows by default, in order; the rest sit under
    /// More. Nil shows every section. Users change it per type or per server (round 16).
    let dock: [ExplorerNodeKind]?

    init(
        dock: [ExplorerNodeKind]? = nil,
        @ExplorerBlueprintBuilder server: () -> [ExplorerBlueprintNode],
        @ExplorerBlueprintBuilder database: () -> [ExplorerBlueprintNode]
    ) {
        self.dock = dock
        self.server = server()
        self.database = database()
    }

    static func blueprint(for databaseType: DatabaseType) -> ExplorerBlueprint {
        switch databaseType {
        case .microsoftSQL: .sqlServer
        case .postgresql: .postgreSQL
        case .mysql: .mySQL
        case .sqlite: .sqlite
        }
    }
}

/// One entry in a blueprint.
nonisolated indirect enum ExplorerBlueprintNode: Sendable {
    /// The Databases section: one row per database, each built from the blueprint's `database`,
    /// then any folders listed after them (SQL Server's Database Snapshots, as in SSMS).
    case databases(extras: [ExplorerBlueprintNode])
    /// A folder (a section heading at server level). `source` names where its items load from;
    /// folders inside it share that source unless they name their own.
    case group(ExplorerNodeKind, source: ExplorerChildSource?, hidesWhenEmpty: Bool, children: [ExplorerBlueprintNode])
    /// The loaded items listed under a kind, such as the logins in Logins.
    case items(ExplorerNodeKind)
    /// One folder per object type, in this order, filled from the database's schema.
    case objectFolderList([ExplorerNodeKind])
    /// A row that opens a tool.
    case action(ExplorerNodeKind)
    /// Entries shown only while the database is online.
    case onlineOnly([ExplorerBlueprintNode])

    /// The kind this entry stands for, when it is a single folder, list or tool.
    var kind: ExplorerNodeKind? {
        switch self {
        case .databases: .databases
        case .group(let kind, _, _, _), .items(let kind), .action(let kind): kind
        case .objectFolderList, .onlineOnly: nil
        }
    }
}

/// Anything that can be written in a blueprint.
nonisolated protocol ExplorerBlueprintEntry: Sendable {
    var node: ExplorerBlueprintNode { get }
}

/// The words a blueprint is written in. They are nested in `ExplorerBlueprint`, so they only
/// exist inside blueprint files.
extension ExplorerBlueprint {
    /// The Databases section, with any folders that follow the databases in it.
    nonisolated struct Databases: ExplorerBlueprintEntry {
        let node: ExplorerBlueprintNode
        init(@ExplorerBlueprintBuilder _ extras: () -> [ExplorerBlueprintNode] = { [] }) {
            node = .databases(extras: extras())
        }
    }

    /// A folder with fixed contents. `loading` names where the items inside it load from.
    nonisolated struct Folder: ExplorerBlueprintEntry {
        let node: ExplorerBlueprintNode

        init(
            _ kind: ExplorerNodeKind,
            loading source: ExplorerChildSource? = nil,
            hidesWhenEmpty: Bool = false,
            @ExplorerBlueprintBuilder _ children: () -> [ExplorerBlueprintNode]
        ) {
            node = .group(kind, source: source, hidesWhenEmpty: hidesWhenEmpty, children: children())
        }
    }

    /// A folder that lists its loaded items and nothing else.
    nonisolated struct ItemFolder: ExplorerBlueprintEntry {
        let node: ExplorerBlueprintNode

        init(_ kind: ExplorerNodeKind, loading source: ExplorerChildSource? = nil) {
            node = .group(kind, source: source, hidesWhenEmpty: false, children: [.items(kind)])
        }
    }

    /// The loaded items of a kind, inside a folder.
    nonisolated struct Items: ExplorerBlueprintEntry {
        let node: ExplorerBlueprintNode
        init(_ kind: ExplorerNodeKind) { node = .items(kind) }
    }

    /// A row that opens a tool.
    nonisolated struct Tool: ExplorerBlueprintEntry {
        let node: ExplorerBlueprintNode
        init(_ kind: ExplorerNodeKind) { node = .action(kind) }
    }

    /// One folder per object type, in this order.
    nonisolated struct ObjectFolders: ExplorerBlueprintEntry {
        let node: ExplorerBlueprintNode
        init(_ kinds: ExplorerNodeKind...) { node = .objectFolderList(kinds) }
    }

    /// Entries shown only while the database is online.
    nonisolated struct WhenOnline: ExplorerBlueprintEntry {
        let node: ExplorerBlueprintNode
        init(@ExplorerBlueprintBuilder _ children: () -> [ExplorerBlueprintNode]) { node = .onlineOnly(children()) }
    }
}

@resultBuilder
nonisolated enum ExplorerBlueprintBuilder {
    static func buildExpression(_ entry: some ExplorerBlueprintEntry) -> [ExplorerBlueprintNode] { [entry.node] }
    static func buildBlock(_ parts: [ExplorerBlueprintNode]...) -> [ExplorerBlueprintNode] { parts.flatMap { $0 } }
    static func buildOptional(_ part: [ExplorerBlueprintNode]?) -> [ExplorerBlueprintNode] { part ?? [] }
    static func buildEither(first part: [ExplorerBlueprintNode]) -> [ExplorerBlueprintNode] { part }
    static func buildEither(second part: [ExplorerBlueprintNode]) -> [ExplorerBlueprintNode] { part }
}

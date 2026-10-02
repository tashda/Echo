import SwiftUI

/// Where Manage Connections opens (kept for callers such as File › Manage Connections).
/// `.projects` opens the current project's settings.
enum ManageSection: String, Identifiable, CaseIterable {
    case connections
    case identities
    case projects

    var id: String { rawValue }
}

/// Round MC: what the sidebar shows in the middle column.
enum ManageScope: Hashable {
    case allConnections
    case recentConnections
    /// One connection folder (round MC, round 2: folders stay, without sign-in).
    case folder(UUID)
    case identities
    /// One identity folder (R2-H, IF2).
    case identityFolder(UUID)

    var title: String {
        switch self {
        case .allConnections: "All Connections"
        case .recentConnections: "Recently Used"
        case .folder, .identityFolder: "Folder"
        case .identities: "Identities"
        }
    }

    var isConnections: Bool {
        switch self {
        case .identities, .identityFolder: false
        default: true
        }
    }

    /// The folder this scope shows, if any.
    var folderID: UUID? {
        switch self {
        case .folder(let id), .identityFolder(let id): id
        default: nil
        }
    }
}

/// A run of rows under one folder heading (R2-G: the sidebar picks a folder; the list and table
/// group what it shows by folder). `folder == nil` is the rows filed directly in the scope.
struct ManageGroup<Item: Identifiable>: Identifiable where Item.ID == UUID {
    let folder: SavedFolder?
    /// "Production / EU", relative to the scope.
    let title: String?
    let items: [Item]
    var id: UUID { folder?.id ?? ManageGroupID.loose }
}

enum ManageGroupID {
    /// The group of rows filed directly in the scope.
    static let loose = UUID(uuidString: "00000000-0000-0000-0000-00000000F01D")!
}

/// A row of the connections table: a folder heading (a disclosure row) or a connection.
enum ConnectionTableItem: Identifiable, Hashable {
    case folder(SavedFolder, title: String)
    case connection(SavedConnection)

    var id: UUID {
        switch self {
        case .folder(let folder, _): folder.id
        case .connection(let connection): connection.id
        }
    }

    /// The name the Name column sorts by.
    var name: String {
        switch self {
        case .folder(_, let title): title
        case .connection(let connection):
            let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? connection.host : trimmed
        }
    }

    var host: String {
        if case .connection(let connection) = self { return connection.host }
        return ""
    }

    var connection: SavedConnection? {
        if case .connection(let connection) = self { return connection }
        return nil
    }
}

/// Round MC (MA1): two-line rows beside the editor by default; a table on ⌘2.
enum ConnectionsViewMode: String {
    case list
    case table
}

/// The folder name alert: a new folder (under a parent, optionally moving connections into it)
/// or a rename.
enum FolderNameRequest: Identifiable, Equatable {
    case create(kind: FolderKind, parentID: UUID?, moving: Set<UUID>)
    case rename(SavedFolder)

    var id: String {
        switch self {
        case .create(let kind, let parentID, _): "create-\(kind.rawValue)-\(parentID?.uuidString ?? "top")"
        case .rename(let folder): "rename-\(folder.id.uuidString)"
        }
    }
}

/// A move away from an editor that has unsaved changes, waiting for Save, Don't Save or Cancel.
enum PendingNavigation: Equatable {
    case connections(Set<SavedConnection.ID>)
    case identities(Set<SavedIdentity.ID>)
    case scope(ManageScope)
    case newConnection
    case newIdentity
}

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

    var title: String {
        switch self {
        case .allConnections: "All Connections"
        case .recentConnections: "Recently Used"
        case .folder: "Folder"
        case .identities: "Identities"
        }
    }

    var isConnections: Bool { self != .identities }
}

/// Round MC (MA1): two-line rows beside the editor by default; a table on ⌘2.
enum ConnectionsViewMode: String {
    case list
    case table
}

/// The folder name alert: a new folder (under a parent, optionally moving connections into it)
/// or a rename.
enum FolderNameRequest: Identifiable, Equatable {
    case create(parentID: UUID?, moving: Set<UUID>)
    case rename(SavedFolder)

    var id: String {
        switch self {
        case .create(let parentID, _): "create-\(parentID?.uuidString ?? "top")"
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

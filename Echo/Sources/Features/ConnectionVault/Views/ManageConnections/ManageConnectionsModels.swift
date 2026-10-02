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
    case identities

    var title: String {
        switch self {
        case .allConnections: "All Connections"
        case .recentConnections: "Recently Used"
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

/// A move away from an editor that has unsaved changes, waiting for Save, Don't Save or Cancel.
enum PendingNavigation: Equatable {
    case connections(Set<SavedConnection.ID>)
    case identities(Set<SavedIdentity.ID>)
    case scope(ManageScope)
    case newConnection
    case newIdentity
}

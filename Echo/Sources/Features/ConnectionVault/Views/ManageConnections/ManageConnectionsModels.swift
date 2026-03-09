import SwiftUI

enum ManageSection: String, Identifiable, CaseIterable {
    case connections
    case identities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connections: return "Connections"
        case .identities: return "Identities"
        }
    }

    var icon: String {
        switch self {
        case .connections: return "externaldrive.connected.to.line.below"
        case .identities: return "person.crop.circle"
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .connections: return "Search connections…"
        case .identities: return "Search identities…"
        }
    }

    var emptyTitle: String {
        switch self {
        case .connections: return "No Connections"
        case .identities: return "No Identities"
        }
    }

    var emptyMessage: String {
        switch self {
        case .connections: return "You haven't added any database connections to this project yet."
        case .identities: return "Project identities help you manage credentials separately from connections."
        }
    }

    var emptyActionTitle: String {
        switch self {
        case .connections: return "Add Connection"
        case .identities: return "Add Identity"
        }
    }
}

enum SidebarSelection: Hashable {
    case section(ManageSection)
    case folder(UUID, ManageSection)

    var section: ManageSection {
        switch self {
        case .section(let s): return s
        case .folder(_, let s): return s
        }
    }
}

struct FolderNode: Identifiable {
    let folder: SavedFolder
    let childNodes: [FolderNode]?
    var id: UUID { folder.id }
    
    // Helper for total count
    var totalItemCount: Int = 0
}

struct ConnectionEditorPresentation: Identifiable {
    let id = UUID()
    let connection: SavedConnection?
}

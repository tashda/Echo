import SwiftUI

enum ManageSection: String, Identifiable, CaseIterable {
    case connections
    case identities
    case projects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connections: return "Connections"
        case .identities: return "Identities"
        case .projects: return "Projects"
        }
    }

    var icon: String {
        switch self {
        case .connections: return "externaldrive.connected.to.line.below"
        case .identities: return "person.crop.circle"
        case .projects: return "folder"
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .connections: return "Search connections…"
        case .identities: return "Search identities…"
        case .projects: return "Search projects…"
        }
    }

    var emptyTitle: String {
        switch self {
        case .connections: return "No Connections"
        case .identities: return "No Identities"
        case .projects: return "No Projects"
        }
    }

    var emptyMessage: String {
        switch self {
        case .connections: return "You haven't added any database connections to this project yet."
        case .identities: return "Project identities help you manage credentials separately from connections."
        case .projects: return "Projects help you organize your database connections and identities."
        }
    }

    var emptyActionTitle: String {
        switch self {
        case .connections: return "Add Connection"
        case .identities: return "Add Identity"
        case .projects: return "New Project"
        }
    }
}

enum SidebarSelection: Hashable {
    case section(ManageSection)
    case folder(UUID, ManageSection)
    case project(UUID)

    var section: ManageSection {
        switch self {
        case .section(let s): return s
        case .folder(_, let s): return s
        case .project: return .projects
        }
    }
}

struct FolderNode: Identifiable {
    let folder: SavedFolder
    var childNodes: [FolderNode]?
    var items: [AnyHashable] = []
    var id: UUID { folder.id }

    // Helper for total count
    var totalItemCount: Int = 0
}


struct ConnectionEditorPresentation: Identifiable {
    let id = UUID()
    let connection: SavedConnection?
}

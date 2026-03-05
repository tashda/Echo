import Foundation

enum DeletionTarget: Identifiable {
    case connection(SavedConnection)
    case folder(SavedFolder)
    case identity(SavedIdentity)

    var id: UUID {
        switch self {
        case .connection(let c): return c.id
        case .folder(let f): return f.id
        case .identity(let i): return i.id
        }
    }

    var displayName: String {
        switch self {
        case .connection(let c): return c.connectionName
        case .folder(let f): return f.name
        case .identity(let i): return i.name
        }
    }
}

enum FolderEditorState: Identifiable {
    case create(kind: FolderKind, parent: SavedFolder?, token: UUID)
    case edit(folder: SavedFolder)

    var id: UUID {
        switch self {
        case .create(_, _, let token): return token
        case .edit(let folder): return folder.id
        }
    }
}

enum IdentityEditorState: Identifiable {
    case create(parent: SavedFolder?, token: UUID)
    case edit(identity: SavedIdentity)

    var id: UUID {
        switch self {
        case .create(_, let token): return token
        case .edit(let identity): return identity.id
        }
    }
}

enum FolderIdentityPalette {
    static let defaults: [String] = [
        "BAF2BB", "BAF2D8", "BAD7F2", "F2BAC9", "F2E2BA"
    ]
}

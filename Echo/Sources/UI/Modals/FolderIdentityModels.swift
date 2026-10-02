import Foundation

enum DeletionTarget: Identifiable {
    case connection(SavedConnection)
    case identity(SavedIdentity)

    var id: UUID {
        switch self {
        case .connection(let c): return c.id
        case .identity(let i): return i.id
        }
    }

    var displayName: String {
        switch self {
        case .connection(let c): return c.connectionName
        case .identity(let i): return i.name
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

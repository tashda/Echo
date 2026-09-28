import Foundation

enum ConnectionDockEntry: Identifiable {
    enum ID: Hashable {
        case session(UUID)
        case pending(UUID)
    }

    case session(ConnectionSession)
    case pending(PendingConnection)

    var id: ID {
        switch self {
        case .session(let session):
            return .session(session.id)
        case .pending(let pending):
            return .pending(pending.id)
        }
    }

    var connectionID: UUID {
        switch self {
        case .session(let session):
            return session.connection.id
        case .pending(let pending):
            return pending.connection.id
        }
    }
}

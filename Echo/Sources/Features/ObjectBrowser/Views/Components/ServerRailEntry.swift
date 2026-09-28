import Foundation

/// One item in the server rail: a live session or a connection still being established.
enum ServerRailEntry: Identifiable {
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

    var connection: SavedConnection {
        switch self {
        case .session(let session):
            return session.connection
        case .pending(let pending):
            return pending.connection
        }
    }

    var connectionID: UUID {
        connection.id
    }

    var displayName: String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }

    @MainActor var status: ServerRailStatus {
        switch self {
        case .session(let session):
            return ServerRailStatus(session.connectionState)
        case .pending(let pending):
            switch pending.phase {
            case .connecting: return .connecting
            case .failed: return .failed
            }
        }
    }
}

/// What the rail shows about a server's connection. Healthy servers show nothing extra.
enum ServerRailStatus: Equatable {
    case ready
    case connecting
    case failed

    init(_ state: ConnectionState) {
        switch state {
        case .connected: self = .ready
        case .connecting, .testing: self = .connecting
        case .disconnected, .error: self = .failed
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .ready: return "Connected"
        case .connecting: return "Connecting"
        case .failed: return "Connection lost"
        }
    }
}

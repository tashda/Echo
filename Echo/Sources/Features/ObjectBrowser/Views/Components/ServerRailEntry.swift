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

    /// Why the connection was lost, if it was.
    @MainActor var failureReason: String? {
        switch self {
        case .session(let session):
            switch session.connectionState {
            case .error(let error): return error.errorDescription ?? error.localizedDescription
            case .disconnected: return "Disconnected"
            case .connected, .connecting, .testing: return nil
            }
        case .pending(let pending):
            if case .failed(let message) = pending.phase { return message }
            return nil
        }
    }

    /// The product and release, as the server header says it (round 51, NM1).
    @MainActor var productLine: String {
        switch self {
        case .session(let session):
            return ServerProductLabel.label(
                rawVersion: session.databaseStructure?.serverVersion ?? session.connection.serverVersion,
                databaseType: session.connection.databaseType
            )
        case .pending(let pending):
            return ServerProductLabel.label(rawVersion: pending.connection.serverVersion, databaseType: pending.connection.databaseType)
        }
    }

    /// The line the name bubble adds under the product when something needs saying: the server is
    /// connecting, the connection was lost, or queries are running. A healthy idle server has none.
    @MainActor func statusLine(runningQueryCount: Int) -> String? {
        switch status {
        case .connecting:
            return "Connecting"
        case .failed:
            return failureReason.map { "Connection lost: \($0)" } ?? "Connection lost"
        case .ready:
            if runningQueryCount == 1 { return "1 query running" }
            return runningQueryCount > 1 ? "\(runningQueryCount) queries running" : nil
        }
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

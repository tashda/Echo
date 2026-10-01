import Foundation
import PostgresKit

/// A PostgreSQL connection with several servers moved to another one (Echo Labs round 23, FS1).
struct ConnectionServerMove: Equatable, Sendable {
    let from: String
    let to: String
    /// "primary" or "standby" when Connect To asked for one, so the new server is that.
    let role: String?
    let date: Date

    /// The footer chip: "db2 · primary".
    var label: String { role.map { "\(to) · \($0)" } ?? to }
    var help: String { "Moved from \(from) at \(date.formatted(date: .omitted, time: .shortened))" }
}

extension ConnectionSession {
    /// Follows the pool's failovers for a PostgreSQL connection with several servers: records the
    /// move for the footer chip and reports it once.
    func startServerWatch(onMove: @escaping @MainActor (ConnectionServerMove) -> Void) {
        serverWatchTask?.cancel()
        guard connection.databaseType == .postgresql, !connection.additionalHosts.isEmpty,
              let postgres = session as? PostgresSession else { return }
        let changes = postgres.client.hostChanges()
        let role: String? = switch connection.targetSessionAttributes {
        case .primary, .readWrite: "primary"
        case .standby, .readOnly: "standby"
        default: nil
        }
        serverWatchTask = Task { @MainActor [weak self] in
            for await change in changes {
                guard let self, !Task.isCancelled else { return }
                let names = PostgresConnectionTest.displayNames([change.from, change.to])
                let move = ConnectionServerMove(from: names[0], to: names[1], role: role, date: change.date)
                self.serverMove = move
                onMove(move)
            }
        }
    }
}

extension EnvironmentState {
    /// "Reporting moved to db2": a notification (with the history record), as round 21 reports a
    /// lost connection.
    func announceServerMove(_ move: ConnectionServerMove, for session: ConnectionSession) {
        let name = session.connection.connectionName.isEmpty ? session.connection.host : session.connection.connectionName
        let now = move.role.map { ", the \($0) now" } ?? ""
        notificationEngine?.post(
            category: .connectionDisconnected,
            icon: "arrow.triangle.swap",
            message: "\(name) moved to \(move.to)\(now). \(move.from) stopped answering; query tabs that were on it lost their connection.",
            style: .warning,
            duration: 8,
            context: NotificationContext(serverName: name, connectionID: session.connection.id, tabID: nil)
        )
    }
}

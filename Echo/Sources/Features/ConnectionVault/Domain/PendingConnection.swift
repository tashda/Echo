import Foundation
import Observation

// MARK: - Pending Connection Phase

enum PendingConnectionPhase: Equatable {
    case connecting
    case failed(message: String)
}

// MARK: - Pending Connection

/// Represents a connection attempt that has not yet completed.
///
/// Created immediately when the user initiates a connection and lives in
/// `EnvironmentState.pendingConnections` until the connection either succeeds
/// (removed, replaced by a `ConnectionSession`) or fails (stays with `.failed` phase).
@Observable
final class PendingConnection: Identifiable {
    let id: UUID
    let connection: SavedConnection
    var phase: PendingConnectionPhase = .connecting
    @ObservationIgnored var connectTask: Task<Void, Never>?

    init(connection: SavedConnection) {
        self.id = connection.id
        self.connection = connection
    }
}

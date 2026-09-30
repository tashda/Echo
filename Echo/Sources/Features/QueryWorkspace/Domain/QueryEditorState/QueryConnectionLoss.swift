import Foundation

/// A query tab whose connection dropped (Echo Labs round 21, connection lost). The footer's status
/// says Disconnected while it is set.
enum QueryConnectionLoss: Equatable, Sendable {
    /// Nothing was open; the next run reconnects (I1 · quietly).
    case idle(database: String)
    /// A transaction was rolled back; runs wait for Reconnect (RC2).
    case transactionLost(database: String)

    var database: String {
        switch self {
        case .idle(let database), .transactionLost(let database): database
        }
    }
}

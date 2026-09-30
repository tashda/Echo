import Foundation

/// What Echo says when a query tab's connection drops (Echo Labs round 21, connection lost, WD2 ·
/// what it means for your work; SQL Server follows it, round 22 LC4). Notifications split title
/// and detail at the first ": ".
nonisolated enum QueryConnectionLossText {
    /// In the tab's Messages, when the connection drops with a transaction open.
    static func droppedWithTransaction(database: String) -> String {
        "Connection lost: the connection to \(database) dropped while a transaction was open. The server rolled the transaction back; nothing since BEGIN was saved. Reconnect to start a new session. Details: the server or the network closed the connection."
    }

    /// The notification (and history row) for the same drop.
    static func notification(tabTitle: String, database: String) -> String {
        "Connection lost: \(tabTitle) (\(database)) had a transaction open. The server rolled it back; nothing since BEGIN was saved."
    }

    /// Recorded in the history only, when the connection drops with nothing open.
    static func droppedIdle(tabTitle: String, database: String) -> String {
        "Connection closed: \(tabTitle) (\(database)) was idle, so nothing was lost. The next run reconnects."
    }

    /// A run while the tab waits for Reconnect.
    static func awaitingReconnect(database: String) -> String {
        "Not connected: the connection to \(database) was lost with a transaction open, and the server rolled it back. Press Reconnect in the notification to start a new session (SET and temporary tables will be gone)."
    }

    /// After Reconnect.
    static func reconnected(database: String) -> String {
        "Reconnected to \(database): a new session. SET, temporary tables and the lost transaction are gone."
    }

    static func reconnectFailed(database: String, reason: String) -> String {
        "Reconnect failed: could not connect to \(database). \(reason)"
    }
}

import Foundation

/// The three lines of the rail's name bubble (round 51, NM1) for one item.
nonisolated struct ServerRailBubbleCaption: Equatable, Sendable {
    let name: String
    let product: String
    let status: String?

    /// What the bubble says under a recent server's product: it is not connected and a click
    /// connects it, or that it is connecting.
    static func recentStatus(isConnecting: Bool) -> String {
        isConnecting ? "Connecting" : "Not connected, click to connect"
    }
}

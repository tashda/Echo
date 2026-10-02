import Foundation

/// The three lines of the rail's name bubble (round 51, NM1) for one item.
nonisolated struct ServerRailBubbleCaption: Equatable, Sendable {
    let name: String
    let product: String
    let status: String?

    /// What the bubble says under a recent server's product: nothing while it rests (its dimming
    /// and place already say it is not connected), "Connecting" while it connects.
    static func recentStatus(isConnecting: Bool) -> String? {
        isConnecting ? "Connecting" : nil
    }
}

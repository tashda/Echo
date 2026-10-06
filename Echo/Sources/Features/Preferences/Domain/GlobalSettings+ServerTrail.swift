import Foundation

/// How many recent servers the trail shows under the connected servers (round 55, SE0).
enum RecentServerCount: Int, Codable, CaseIterable, Sendable {
    case three = 3
    case five = 5
    case eight = 8

    var displayName: String { String(rawValue) }
}

/// Where a card goes when it is closed with its header's chevron.
enum ClosedCardDestination: String, Codable, CaseIterable, Sendable {
    /// The card leaves the tree and its server stays in the server trail, below the hairline (round 51, 55).
    case serverTrail
    /// The card stays in the tree as its header alone.
    case headerCard

    var displayName: String {
        switch self {
        case .serverTrail: "Server Trail"
        case .headerCard: "Header Card"
        }
    }
}

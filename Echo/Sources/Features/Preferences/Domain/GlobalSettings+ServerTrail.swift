import Foundation

/// How many recent servers the trail shows under the connected servers (round 55, SE0).
enum RecentServerCount: Int, Codable, CaseIterable, Sendable {
    case three = 3
    case five = 5
    case eight = 8

    var displayName: String { String(rawValue) }
}

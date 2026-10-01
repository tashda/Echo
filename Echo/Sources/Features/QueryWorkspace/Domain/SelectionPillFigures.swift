import Foundation

/// What the results footer's selection pill says besides the count (owner, after round 41.2):
/// Settings › Results › Selection summary. The exact figures are always in its popover.
enum SelectionPillFigures: String, Codable, CaseIterable, Hashable, Sendable {
    case count
    case countAndSum
    case countAndAverage
    case countSumAndAverage

    var displayName: String {
        switch self {
        case .count: "Count"
        case .countAndSum: "Count and sum"
        case .countAndAverage: "Count and average"
        case .countSumAndAverage: "Count, sum and average"
        }
    }

    var showsSum: Bool { self == .countAndSum || self == .countSumAndAverage }
    var showsAverage: Bool { self == .countAndAverage || self == .countSumAndAverage }
}

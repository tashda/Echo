import Foundation

/// Round 28.8: the editor's zoom, per tab and not saved (ZS0), in the steps of ZR0. It scales the
/// editor's font, so the gutter's numbers follow (round 28.2); the results don't zoom (ZW0).
nonisolated enum EditorZoom {
    static let levels: [Double] = [0.5, 0.75, 0.9, 1, 1.1, 1.25, 1.5, 2]
    static let actualSize: Double = 1

    /// The next level up (+1) or down (-1) from `zoom`, staying within the levels.
    static func step(_ zoom: Double, by direction: Int) -> Double {
        if direction > 0 { return levels.first { $0 > zoom + 0.001 } ?? levels[levels.count - 1] }
        return levels.last { $0 < zoom - 0.001 } ?? levels[0]
    }

    /// “125%”.
    static func label(_ zoom: Double) -> String {
        "\(Int((zoom * 100).rounded()))%"
    }
}

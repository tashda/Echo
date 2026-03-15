import Foundation

internal let streamingRowPresets: [Int] = [100, 250, 500, 750, 1_000, 2_000, 5_000, 10_000]

internal enum ResultStreamingDefaults {
    static let initialRows = 500
    static let previewBatch = 500
}

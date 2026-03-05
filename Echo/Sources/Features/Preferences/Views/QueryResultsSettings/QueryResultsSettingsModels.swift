import Foundation

internal let streamingRowPresets: [Int] = [100, 250, 500, 750, 1_000, 2_000, 5_000, 10_000]
internal let streamingThresholdPresets: [Int] = [512, 1_000, 2_000, 5_000, 10_000, 20_000, 50_000, 100_000, 250_000, 500_000, 1_000_000]
internal let streamingFetchPresets: [Int] = [128, 256, 384, 512, 768, 1_024, 2_048, 4_096, 8_192, 16_384]
internal let streamingFetchRampMultiplierPresets: [Int] = [2, 4, 6, 8, 12, 16, 24, 32, 48, 64]
internal let streamingFetchRampMaxPresets: [Int] = [32_768, 65_536, 131_072, 262_144, 524_288, 786_432, 1_048_576]

internal enum ResultStreamingDefaults {
    static let initialRows = 500
    static let previewBatch = 500
    static let backgroundThreshold = 512
    static let fetchSize = 4_096
    static let fetchRampMultiplier = 24
    static let fetchRampMax = 524_288
    // Default to auto mode via cursor heuristic (ON), so Echo chooses the fastest path per query.
    static let useCursor = true
    // Route LIMITed queries like 100k to simple path by default; large/no LIMIT use cursor.
    static let cursorLimitThreshold = 25_000
}

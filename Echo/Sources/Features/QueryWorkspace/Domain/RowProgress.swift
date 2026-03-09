import Foundation

struct RowProgress: Equatable {
    /// Rows that have been received from the stream (cumulative)
    var totalReceived: Int = 0

    /// Total row count reported by the database/stream
    var totalReported: Int = 0

    /// Rows that are fully materialized and ready to display
    var materialized: Int = 0

    /// Backwards-compatible alias for `totalReported`
    var reported: Int {
        get { totalReported }
        set { totalReported = newValue }
    }

    /// Backwards-compatible alias for `totalReceived`
    var received: Int {
        get { totalReceived }
        set { totalReceived = newValue }
    }

    init(totalReceived: Int = 0, totalReported: Int = 0, materialized: Int = 0) {
        self.totalReceived = totalReceived
        self.totalReported = totalReported
        self.materialized = materialized
    }

    init(materialized: Int, reported: Int, received: Int? = nil) {
        self.init(
            totalReceived: received ?? max(materialized, reported),
            totalReported: reported,
            materialized: materialized
        )
    }

    /// Primary count to display in UI (auto-selects best available count)
    var displayCount: Int {
        totalReported > 0 ? totalReported : totalReceived
    }

    /// Whether the query has completed loading all rows
    var isComplete: Bool {
        totalReported > 0 && materialized >= totalReported
    }
}

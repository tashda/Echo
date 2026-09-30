import EchoSense
import Foundation

extension GridSelectionSummary {
    /// The footer's row count: rows loaded of the total while a query streams
    /// ("12K of 1.2M"), otherwise the total.
    static func rowCountText(for progress: RowProgress, isExecuting: Bool, compact: (Int) -> String) -> String {
        if isExecuting, progress.totalReported > 0, progress.materialized < progress.totalReported {
            return "\(compact(progress.materialized)) of \(compact(progress.totalReported))"
        }
        return compact(progress.displayCount)
    }
}

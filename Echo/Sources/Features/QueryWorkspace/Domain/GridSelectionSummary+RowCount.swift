import EchoSense
import Foundation

extension GridSelectionSummary {
    /// The footer's row count: every row the server has sent so far, counting up
    /// while a query streams ("12K"), never "12K of 1.2M".
    static func rowCountText(for progress: RowProgress, compact: (Int) -> String) -> String {
        compact(progress.displayCount)
    }
}

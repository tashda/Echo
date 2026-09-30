import EchoSense
import Foundation

/// What the results footer says about the selected cells (Design/05-components.md › Results card,
/// plan R5): how many, and the sum and average of the numeric ones.
nonisolated struct GridSelectionSummary: Equatable, Sendable {
    let cellCount: Int
    let numericCount: Int
    let sum: Double
    /// False when the selection was too large to add up; only the count is shown then.
    let isComplete: Bool

    var average: Double? { numericCount > 0 ? sum / Double(numericCount) : nil }

    /// Selections larger than this show a count only, so selecting a huge column stays instant.
    static let maximumSummedCells = 50_000

    /// Adds up `values`; non-numeric and NULL cells count as cells but not towards the sum.
    static func summarize(_ values: some Sequence<String?>, cellCount: Int) -> GridSelectionSummary {
        guard cellCount <= maximumSummedCells else {
            return GridSelectionSummary(cellCount: cellCount, numericCount: 0, sum: 0, isComplete: false)
        }
        var numericCount = 0
        var sum = 0.0
        for value in values {
            guard let value, let number = Double(value.trimmingCharacters(in: .whitespaces)), number.isFinite else { continue }
            numericCount += 1
            sum += number
        }
        return GridSelectionSummary(cellCount: cellCount, numericCount: numericCount, sum: sum, isComplete: true)
    }

    /// "3 cells · Sum 1,234 · Avg 411.33", or just the count when nothing numeric is selected.
    var text: String {
        let count = cellCount.formatted()
        var parts = [cellCount == 1 ? "1 cell" : "\(count) cells"]
        if isComplete, numericCount > 1, let average {
            let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2))
            parts.append("Sum \(sum.formatted(style))")
            parts.append("Avg \(average.formatted(style))")
        }
        return parts.joined(separator: " · ")
    }

    /// The footer's row count: rows loaded of the total while a query streams
    /// ("12K of 1.2M"), otherwise the total.
    static func rowCountText(for progress: RowProgress, isExecuting: Bool, compact: (Int) -> String) -> String {
        if isExecuting, progress.totalReported > 0, progress.materialized < progress.totalReported {
            return "\(compact(progress.materialized)) of \(compact(progress.totalReported))"
        }
        return compact(progress.displayCount)
    }
}

import EchoSense
import Testing
@testable import Echo

@Suite("Grid selection summary")
struct GridSelectionSummaryTests {
    @Test func sumsNumericCellsOnly() {
        let summary = GridSelectionSummary.summarize(["10", "20", "abc", nil], cellCount: 4)
        #expect(summary.cellCount == 4)
        #expect(summary.numericCount == 2)
        #expect(summary.sum == 30)
        #expect(summary.average == 15)
        #expect(summary.text.hasPrefix("4 cells · Sum 30"))
    }

    @Test func hugeSelectionsAreOnlyCounted() {
        let summary = GridSelectionSummary.summarize([String?](), cellCount: GridSelectionSummary.maximumSummedCells + 1)
        #expect(!summary.isComplete)
        #expect(!summary.text.contains("Sum"))
    }

    @Test func rowCountShowsLoadedOfTotalWhileStreaming() {
        var progress = RowProgress()
        progress.totalReported = 1_000
        progress.materialized = 200
        let compact: (Int) -> String = { String($0) }
        #expect(GridSelectionSummary.rowCountText(for: progress, isExecuting: true, compact: compact) == "200 of 1000")
        #expect(GridSelectionSummary.rowCountText(for: progress, isExecuting: false, compact: compact) == "1000")
    }
}

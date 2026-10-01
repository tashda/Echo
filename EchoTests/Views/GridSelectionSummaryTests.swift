import EchoSense
import Foundation
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
        #expect(summary.text == "4 cells")
        #expect(summary.distinctCount == 3)
        #expect(summary.emptyCount == 1)
    }

    @Test func thePopoverListsEveryFigureForNumbers() {
        let summary = GridSelectionSummary.summarize(["3", "1", "2", nil], cellCount: 4, columnName: "bagno")
        let english = Locale(identifier: "en_US")
        #expect(summary.columnName == "bagno")
        #expect(summary.figures(locale: english).map { $0.label } == ["Count", "Sum", "Average", "Min", "Max", "Median", "Distinct", "Empty"])
        #expect(summary.copyAllText(locale: english).hasPrefix("Count\t4\nSum\t6\n"))
    }

    @Test func textCellsListOnlyCountDistinctAndEmpty() {
        let summary = GridSelectionSummary.summarize(["DK", "SE", "DK"], cellCount: 3)
        #expect(summary.figures(locale: Locale(identifier: "en_US")).map { $0.label } == ["Count", "Distinct", "Empty"])
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

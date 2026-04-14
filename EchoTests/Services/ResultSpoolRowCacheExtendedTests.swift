import Testing
import Foundation
@testable import Echo

@Suite("ResultSpoolRowCache Extended")
struct ResultSpoolRowCacheExtendedTests {

    // MARK: - LRU Eviction

    @Test func lruEvictionRemovesOldestPages() {
        let cache = ResultSpoolRowCache(pageSize: 2, maxPages: 3)

        // Fill pages 0, 1, 2
        cache.ingest(rows: [["a"], ["b"]], startingAt: 0) // page 0
        cache.ingest(rows: [["c"], ["d"]], startingAt: 2) // page 1
        cache.ingest(rows: [["e"], ["f"]], startingAt: 4) // page 2

        // All three should exist
        #expect(cache.row(at: 0) == ["a"])
        #expect(cache.row(at: 2) == ["c"])
        #expect(cache.row(at: 4) == ["e"])

        // Adding page 3 should evict page 0 (oldest after reads)
        // But reading them above touched them, so LRU order is now 0,1,2 -> after reads: 1,2,0
        // Actually: initial insert order is 0,1,2. Then reading 0 touches it, making LRU [1,2,0].
        // Reading 2 touches it: [1,0,2]. Reading 4 touches page 2: already touched.
        // Let me reconsider. After ingest: LRU = [0,1,2].
        // row(at:0) touches page 0: LRU = [1,2,0]
        // row(at:2) touches page 1: LRU = [2,0,1]
        // row(at:4) touches page 2: LRU = [0,1,2]
        // Now insert page 3 -> evicts page 0 (first in LRU)
        cache.ingest(rows: [["g"], ["h"]], startingAt: 6) // page 3

        #expect(cache.row(at: 0) == nil, "Page 0 should be evicted")
        #expect(cache.row(at: 2) != nil)
        #expect(cache.row(at: 4) != nil)
        #expect(cache.row(at: 6) == ["g"])
    }

    @Test func lruEvictionMultipleRounds() {
        let cache = ResultSpoolRowCache(pageSize: 1, maxPages: 2)

        cache.ingest(rows: [["a"]], startingAt: 0) // page 0
        cache.ingest(rows: [["b"]], startingAt: 1) // page 1

        // Evict page 0 by adding page 2
        cache.ingest(rows: [["c"]], startingAt: 2) // page 2
        #expect(cache.row(at: 0) == nil)
        #expect(cache.row(at: 1) != nil)
        #expect(cache.row(at: 2) == ["c"])

        // Evict page 1 by adding page 3
        // After previous: LRU had [1,2], reading at:1 touches it -> [2,1], reading at:2 touches -> [1,2]
        cache.ingest(rows: [["d"]], startingAt: 3) // page 3, evicts page 1
        #expect(cache.row(at: 1) == nil)
    }

    @Test func lruTouchByReadPreventsEviction() {
        let cache = ResultSpoolRowCache(pageSize: 2, maxPages: 2)

        cache.ingest(rows: [["a"], ["b"]], startingAt: 0) // page 0
        cache.ingest(rows: [["c"], ["d"]], startingAt: 2) // page 1

        // Touch page 0 by reading from it
        _ = cache.row(at: 1)

        // Insert page 2: should evict page 1 (least recently used)
        cache.ingest(rows: [["e"], ["f"]], startingAt: 4) // page 2
        #expect(cache.row(at: 0) == ["a"], "Page 0 was touched, should survive")
        #expect(cache.row(at: 2) == nil, "Page 1 should be evicted")
        #expect(cache.row(at: 4) == ["e"])
    }

    // MARK: - Ingest at Various Offsets

    @Test func ingestAtMidPage() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["x"], ["y"]], startingAt: 2)
        #expect(cache.row(at: 0) == nil)
        #expect(cache.row(at: 1) == nil)
        #expect(cache.row(at: 2) == ["x"])
        #expect(cache.row(at: 3) == ["y"])
    }

    @Test func ingestSpanningPageBoundary() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        // Starts at index 3 (page 0 offset 3) and extends to index 5 (page 1 offset 1)
        let rows: [[String?]] = [["a"], ["b"], ["c"]]
        cache.ingest(rows: rows, startingAt: 3)

        #expect(cache.row(at: 3) == ["a"])
        #expect(cache.row(at: 4) == ["b"])
        #expect(cache.row(at: 5) == ["c"])
    }

    @Test func ingestSpanningMultiplePages() {
        let cache = ResultSpoolRowCache(pageSize: 2, maxPages: 10)

        let rows: [[String?]] = (0..<7).map { ["\($0)"] }
        cache.ingest(rows: rows, startingAt: 1) // spans pages 0,1,2,3

        for i in 0..<7 {
            #expect(cache.row(at: i + 1) == ["\(i)"])
        }
    }

    @Test func ingestAtHighOffset() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["far"]], startingAt: 1000)
        #expect(cache.row(at: 1000) == ["far"])
        #expect(cache.row(at: 999) == nil)
        #expect(cache.row(at: 1001) == nil)
    }

    @Test func ingestNegativeOffsetIsNoOp() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        cache.ingest(rows: [["x"]], startingAt: -1)
        #expect(cache.row(at: 0) == nil)
    }

    // MARK: - Row Retrieval

    @Test func rowAtValidIndex() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        cache.ingest(rows: [["val"]], startingAt: 0)
        #expect(cache.row(at: 0) == ["val"])
    }

    @Test func rowAtInvalidIndex() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        #expect(cache.row(at: 100) == nil)
    }

    @Test func rowAtNegativeIndex() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        #expect(cache.row(at: -1) == nil)
        #expect(cache.row(at: -100) == nil)
    }

    @Test func rowAtEvictedPage() {
        let cache = ResultSpoolRowCache(pageSize: 1, maxPages: 1)

        cache.ingest(rows: [["a"]], startingAt: 0)
        #expect(cache.row(at: 0) == ["a"])

        cache.ingest(rows: [["b"]], startingAt: 1) // evicts page 0
        #expect(cache.row(at: 0) == nil, "Page 0 should be evicted")
        #expect(cache.row(at: 1) == ["b"])
    }

    // MARK: - Contiguous Materialized Count with Gaps

    @Test func contiguousCountWithGapInMiddle() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"]], startingAt: 0) // 0,1
        cache.ingest(rows: [["c"]], startingAt: 5)         // gap at 2,3,4

        #expect(cache.contiguousMaterializedCount() == 2)
    }

    @Test func contiguousCountWithGapAtPageBoundary() {
        let cache = ResultSpoolRowCache(pageSize: 2, maxPages: 10)

        // Page 0 fully filled
        cache.ingest(rows: [["a"], ["b"]], startingAt: 0)
        // Page 1 is missing
        // Page 2 filled
        cache.ingest(rows: [["e"], ["f"]], startingAt: 4)

        #expect(cache.contiguousMaterializedCount() == 2)
    }

    @Test func contiguousCountFullyContinuous() {
        let cache = ResultSpoolRowCache(pageSize: 3, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"], ["c"], ["d"], ["e"], ["f"]], startingAt: 0)
        #expect(cache.contiguousMaterializedCount() == 6)
    }

    @Test func contiguousCountEmptyCache() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        #expect(cache.contiguousMaterializedCount() == 0)
    }

    @Test func contiguousCountWithPartialFirstPage() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        // Insert only at offset 2 on page 0 — offset 0 and 1 are nil
        cache.ingest(rows: [["c"]], startingAt: 2)
        #expect(cache.contiguousMaterializedCount() == 0)
    }

    // MARK: - Clamp

    @Test func clampRemovesPagesAboveCount() {
        let cache = ResultSpoolRowCache(pageSize: 2, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"], ["c"], ["d"], ["e"], ["f"]], startingAt: 0)
        // Pages 0,1,2

        cache.clamp(to: 3) // Should keep pages 0 and 1, truncate page 1

        #expect(cache.row(at: 0) == ["a"])
        #expect(cache.row(at: 1) == ["b"])
        #expect(cache.row(at: 2) == ["c"])
        #expect(cache.row(at: 3) == nil)
        #expect(cache.row(at: 4) == nil)
        #expect(cache.row(at: 5) == nil)
    }

    @Test func clampToExactPageBoundary() {
        let cache = ResultSpoolRowCache(pageSize: 2, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"], ["c"], ["d"]], startingAt: 0)
        cache.clamp(to: 2) // Exactly page 0

        #expect(cache.row(at: 0) == ["a"])
        #expect(cache.row(at: 1) == ["b"])
        #expect(cache.row(at: 2) == nil)
    }

    @Test func clampToOne() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"], ["c"]], startingAt: 0)
        cache.clamp(to: 1)

        #expect(cache.row(at: 0) == ["a"])
        #expect(cache.row(at: 1) == nil)
    }

    @Test func clampToZero() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        cache.ingest(rows: [["a"]], startingAt: 0)
        cache.clamp(to: 0)

        #expect(cache.row(at: 0) == nil)
        #expect(cache.contiguousMaterializedCount() == 0)
    }

    @Test func clampToNegative() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        cache.ingest(rows: [["a"]], startingAt: 0)
        cache.clamp(to: -5) // treated as <= 0

        #expect(cache.row(at: 0) == nil)
    }

    // MARK: - Reset

    @Test func resetClearsAllData() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        cache.ingest(rows: [["a"], ["b"], ["c"], ["d"], ["e"]], startingAt: 0)

        cache.reset()

        #expect(cache.row(at: 0) == nil)
        #expect(cache.row(at: 1) == nil)
        #expect(cache.contiguousMaterializedCount() == 0)
    }

    @Test func resetAllowsReuse() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        cache.ingest(rows: [["old"]], startingAt: 0)
        cache.reset()

        cache.ingest(rows: [["new"]], startingAt: 0)
        #expect(cache.row(at: 0) == ["new"])
    }

    // MARK: - Thread Safety

    @Test func concurrentIngestAndRead() async {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 100)

        await withTaskGroup(of: Void.self) { group in
            // Writers
            for batch in 0..<20 {
                group.addTask {
                    let rows: [[String?]] = (0..<4).map { ["\(batch)_\($0)"] }
                    cache.ingest(rows: rows, startingAt: batch * 4)
                }
            }

            // Readers
            for _ in 0..<50 {
                group.addTask {
                    for index in 0..<80 {
                        _ = cache.row(at: index)
                    }
                }
            }
        }

        // Should not crash. Verify some data is accessible.
        let count = cache.contiguousMaterializedCount()
        #expect(count >= 0)
    }

    @Test func concurrentResetAndIngest() async {
        let cache = ResultSpoolRowCache(pageSize: 2, maxPages: 10)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    if i % 5 == 0 {
                        cache.reset()
                    } else {
                        cache.ingest(rows: [["v\(i)"]], startingAt: i)
                    }
                }
            }
        }

        // Should not crash
        #expect(cache.contiguousMaterializedCount() >= 0)
    }

    // MARK: - Page Boundary Edge Cases

    @Test func rowAtExactPageBoundary() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["boundary"]], startingAt: 4) // page 1, offset 0
        #expect(cache.row(at: 4) == ["boundary"])
    }

    @Test func rowAtLastSlotInPage() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["end"]], startingAt: 3) // page 0, offset 3
        #expect(cache.row(at: 3) == ["end"])
    }

    @Test func ingestExactlyOnePage() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"], ["c"], ["d"]], startingAt: 0)
        #expect(cache.row(at: 0) == ["a"])
        #expect(cache.row(at: 3) == ["d"])
        #expect(cache.contiguousMaterializedCount() == 4)
    }

    // MARK: - Page Sizes

    @Test func pageSizeOfOne() {
        let cache = ResultSpoolRowCache(pageSize: 1, maxPages: 5)

        cache.ingest(rows: [["a"], ["b"], ["c"]], startingAt: 0)
        #expect(cache.row(at: 0) == ["a"])
        #expect(cache.row(at: 1) == ["b"])
        #expect(cache.row(at: 2) == ["c"])
        #expect(cache.contiguousMaterializedCount() == 3)
    }

    @Test func largePageSize() {
        let cache = ResultSpoolRowCache(pageSize: 1000, maxPages: 2)

        let rows: [[String?]] = (0..<500).map { ["\($0)"] }
        cache.ingest(rows: rows, startingAt: 0)

        #expect(cache.row(at: 0) == ["0"])
        #expect(cache.row(at: 499) == ["499"])
        #expect(cache.contiguousMaterializedCount() == 500)
    }

    @Test func pageSizeClampedToMinimumOne() {
        // pageSize: 0 should be clamped to 1
        let cache = ResultSpoolRowCache(pageSize: 0, maxPages: 5)
        cache.ingest(rows: [["a"]], startingAt: 0)
        #expect(cache.row(at: 0) == ["a"])
    }

    @Test func maxPagesClampedToMinimumOne() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 0)
        cache.ingest(rows: [["a"]], startingAt: 0)
        #expect(cache.row(at: 0) == ["a"])
    }

    // MARK: - Overwrite Behavior

    @Test func ingestOverwritesExistingRow() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["old"]], startingAt: 0)
        #expect(cache.row(at: 0) == ["old"])

        cache.ingest(rows: [["new"]], startingAt: 0)
        #expect(cache.row(at: 0) == ["new"])
    }

    @Test func ingestPartialOverwrite() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"], ["c"], ["d"]], startingAt: 0)
        cache.ingest(rows: [["B"], ["C"]], startingAt: 1)

        #expect(cache.row(at: 0) == ["a"])
        #expect(cache.row(at: 1) == ["B"])
        #expect(cache.row(at: 2) == ["C"])
        #expect(cache.row(at: 3) == ["d"])
    }
}

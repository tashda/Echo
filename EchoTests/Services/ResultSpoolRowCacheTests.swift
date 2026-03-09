import XCTest
@testable import Echo

final class ResultSpoolRowCacheTests: XCTestCase {

    // MARK: - Basic Ingest and Retrieve

    func testIngestAndRetrieveRows() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        let rows: [[String?]] = [["a", "1"], ["b", "2"], ["c", "3"]]
        cache.ingest(rows: rows, startingAt: 0)

        XCTAssertEqual(cache.row(at: 0), ["a", "1"])
        XCTAssertEqual(cache.row(at: 1), ["b", "2"])
        XCTAssertEqual(cache.row(at: 2), ["c", "3"])
        XCTAssertNil(cache.row(at: 3))
    }

    func testIngestAtOffset() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        let rows: [[String?]] = [["x", "10"], ["y", "20"]]
        cache.ingest(rows: rows, startingAt: 5)

        XCTAssertNil(cache.row(at: 4))
        XCTAssertEqual(cache.row(at: 5), ["x", "10"])
        XCTAssertEqual(cache.row(at: 6), ["y", "20"])
        XCTAssertNil(cache.row(at: 7))
    }

    // MARK: - Contiguous Materialized Count

    func testContiguousMaterializedCount() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"], ["c"], ["d"]], startingAt: 0)
        XCTAssertEqual(cache.contiguousMaterializedCount(), 4)

        cache.ingest(rows: [["e"], ["f"]], startingAt: 4)
        XCTAssertEqual(cache.contiguousMaterializedCount(), 6)
    }

    func testContiguousMaterializedCountWithGap() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"]], startingAt: 0)
        cache.ingest(rows: [["x"], ["y"]], startingAt: 8) // Gap from 2..7

        XCTAssertEqual(cache.contiguousMaterializedCount(), 2)
    }

    // MARK: - LRU Eviction

    func testLRUEvictionWhenExceedingMaxPages() {
        let cache = ResultSpoolRowCache(pageSize: 2, maxPages: 2)

        // Page 0 (indices 0-1)
        cache.ingest(rows: [["a"], ["b"]], startingAt: 0)
        // Page 1 (indices 2-3)
        cache.ingest(rows: [["c"], ["d"]], startingAt: 2)
        // Page 2 (indices 4-5) — should evict page 0
        cache.ingest(rows: [["e"], ["f"]], startingAt: 4)

        XCTAssertNil(cache.row(at: 0), "Page 0 should have been evicted")
        XCTAssertEqual(cache.row(at: 2), ["c"])
        XCTAssertEqual(cache.row(at: 4), ["e"])
    }

    func testLRUTouchPreventsEviction() {
        let cache = ResultSpoolRowCache(pageSize: 2, maxPages: 2)

        // Page 0
        cache.ingest(rows: [["a"], ["b"]], startingAt: 0)
        // Page 1
        cache.ingest(rows: [["c"], ["d"]], startingAt: 2)

        // Touch page 0 by reading from it
        _ = cache.row(at: 0)

        // Page 2 — should evict page 1 (LRU), not page 0 (recently touched)
        cache.ingest(rows: [["e"], ["f"]], startingAt: 4)

        XCTAssertEqual(cache.row(at: 0), ["a"], "Page 0 should still be cached")
        XCTAssertNil(cache.row(at: 2), "Page 1 should have been evicted")
        XCTAssertEqual(cache.row(at: 4), ["e"])
    }

    // MARK: - Clamp

    func testClampTruncatesCache() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)

        cache.ingest(rows: [["a"], ["b"], ["c"], ["d"], ["e"]], startingAt: 0)
        XCTAssertEqual(cache.contiguousMaterializedCount(), 5)

        cache.clamp(to: 3)
        XCTAssertEqual(cache.row(at: 0), ["a"])
        XCTAssertEqual(cache.row(at: 2), ["c"])
        XCTAssertNil(cache.row(at: 3))
    }

    func testClampToZeroClearsEverything() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        cache.ingest(rows: [["a"], ["b"]], startingAt: 0)

        cache.clamp(to: 0)
        XCTAssertNil(cache.row(at: 0))
        XCTAssertEqual(cache.contiguousMaterializedCount(), 0)
    }

    // MARK: - Reset

    func testResetClearsEverything() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        cache.ingest(rows: [["a"], ["b"], ["c"]], startingAt: 0)

        cache.reset()

        XCTAssertNil(cache.row(at: 0))
        XCTAssertEqual(cache.contiguousMaterializedCount(), 0)
    }

    // MARK: - Negative/Edge Cases

    func testNegativeIndexReturnsNil() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        XCTAssertNil(cache.row(at: -1))
    }

    func testEmptyIngestIsNoOp() {
        let cache = ResultSpoolRowCache(pageSize: 4, maxPages: 10)
        cache.ingest(rows: [], startingAt: 0)
        XCTAssertEqual(cache.contiguousMaterializedCount(), 0)
    }
}

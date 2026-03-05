import XCTest
@testable import Echo

final class RowProgressTests: XCTestCase {

    // MARK: - Display Count

    func testDisplayCountPrefersReportedWhenPositive() {
        let progress = RowProgress(totalReceived: 100, totalReported: 500, materialized: 50)
        XCTAssertEqual(progress.displayCount, 500)
    }

    func testDisplayCountFallsBackToReceivedWhenReportedIsZero() {
        let progress = RowProgress(totalReceived: 100, totalReported: 0, materialized: 50)
        XCTAssertEqual(progress.displayCount, 100)
    }

    func testDisplayCountZeroWhenBothZero() {
        let progress = RowProgress()
        XCTAssertEqual(progress.displayCount, 0)
    }

    // MARK: - Is Complete

    func testIsCompleteWhenMaterializedEqualsReported() {
        let progress = RowProgress(totalReceived: 100, totalReported: 100, materialized: 100)
        XCTAssertTrue(progress.isComplete)
    }

    func testIsCompleteWhenMaterializedExceedsReported() {
        let progress = RowProgress(totalReceived: 100, totalReported: 80, materialized: 100)
        XCTAssertTrue(progress.isComplete)
    }

    func testIsNotCompleteWhenReportedIsZero() {
        let progress = RowProgress(totalReceived: 100, totalReported: 0, materialized: 100)
        XCTAssertFalse(progress.isComplete)
    }

    func testIsNotCompleteWhenMaterializedLessThanReported() {
        let progress = RowProgress(totalReceived: 100, totalReported: 100, materialized: 50)
        XCTAssertFalse(progress.isComplete)
    }

    // MARK: - Backward Compatibility Aliases

    func testReportedAliasForTotalReported() {
        var progress = RowProgress(totalReceived: 0, totalReported: 42)
        XCTAssertEqual(progress.reported, 42)

        progress.reported = 99
        XCTAssertEqual(progress.totalReported, 99)
    }

    func testReceivedAliasForTotalReceived() {
        var progress = RowProgress(totalReceived: 55, totalReported: 0)
        XCTAssertEqual(progress.received, 55)

        progress.received = 77
        XCTAssertEqual(progress.totalReceived, 77)
    }

    // MARK: - Convenience Init

    func testConvenienceInitSetsReceivedToMaxWhenNil() {
        let progress = RowProgress(materialized: 30, reported: 100)
        XCTAssertEqual(progress.totalReceived, 100) // max(30, 100)
    }

    func testConvenienceInitUsesExplicitReceived() {
        let progress = RowProgress(materialized: 30, reported: 100, received: 50)
        XCTAssertEqual(progress.totalReceived, 50)
    }

    // MARK: - Equatable

    func testEquatable() {
        let a = RowProgress(totalReceived: 10, totalReported: 20, materialized: 5)
        let b = RowProgress(totalReceived: 10, totalReported: 20, materialized: 5)
        XCTAssertEqual(a, b)
    }
}

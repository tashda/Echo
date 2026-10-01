import Foundation
import Testing
@testable import Echo

@Suite("Time since")
struct SinceDateTextTests {
    private let now = Date(timeIntervalSince1970: 10_000)

    @Test func frozenReadsLikeALiveRelativeDate() {
        #expect(SinceDateText.frozen(since: now.addingTimeInterval(-5), now: now) == "5 sec")
        #expect(SinceDateText.frozen(since: now.addingTimeInterval(-185), now: now) == "3 min, 5 sec")
    }

    @Test func aDateInTheFutureReadsAsNoTime() {
        #expect(SinceDateText.frozen(since: now.addingTimeInterval(30), now: now) == "0 sec")
    }
}
